import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui
import "i18n/I18n.js" as I18n

BarWidget {
  id: root
  moduleName: "omarchy-airplay"

  readonly property string ctlPath: String(Qt.resolvedUrl("bin/omarchy-airplay-ctl")).replace(/^file:\/\//, "")
  readonly property string localeName: Qt.locale().name

  property var receivers: []
  property string selectedName: ""
  property string selectedAddress: ""
  property string selectedDeviceId: ""
  property bool pairingRequired: false
  property bool pairingPromptActive: false
  property string discoveryError: ""
  property string streamError: ""
  property bool deliberateStop: false
  property string queuedPairCode: ""
  property string pendingStartPairCode: ""
  property bool pairingAttemptInFlight: false

  readonly property bool mirroring: mirrorProcess.running
  readonly property bool opened: panelLoader.item ? panelLoader.item.opened === true : false

  readonly property var mirroredProperties: [
    "bar", "settings", "receivers", "selectedName", "selectedAddress",
    "selectedDeviceId", "pairingRequired", "pairingPromptActive", "discoveryError", "streamError", "mirroring"
  ]

  function boolSetting(key, fallback) {
    var value = root.setting(key, fallback)
    if (typeof value === "boolean") return value
    return String(value).toLowerCase() === "true"
  }

  function t(key, values) { return I18n.t(root.localeName, key, values) }

  function notify(title, message) {
    Quickshell.execDetached(["omarchy-notification-send", "-g", "󰐨", title, message])
  }

  function injectPanel() {
    var target = panelLoader.item
    if (!target) return
    if ("anchorItem" in target) target.anchorItem = button
    if ("hostWidget" in target) target.hostWidget = root
    for (var i = 0; i < root.mirroredProperties.length; i++) {
      var name = root.mirroredProperties[i]
      if (name in target) target[name] = root[name]
    }
  }

  function open() {
    if (panelLoader.item) panelLoader.item.open()
    root.discover()
  }

  function close() {
    if (panelLoader.item) panelLoader.item.close()
  }

  function togglePanel() {
    if (root.opened) root.close()
    else root.open()
  }

  function discover() {
    if (discoverProcess.running) return
    root.discoveryError = ""
    discoverProcess.command = [root.ctlPath, "discover"]
    discoverProcess.running = true
    root.injectPanel()
  }

  function parseReceivers(text) {
    var found = []
    var lines = String(text).trim().split("\n")
    for (var i = 0; i < lines.length; i++) {
      if (lines[i] === "") continue
      var fields = lines[i].split("\t")
      if (fields.length >= 2) found.push({
        name: fields[0],
        address: fields[1],
        deviceId: fields[2] || "",
        paired: fields[3] === "1"
      })
    }
    return found
  }

  function selectReceiver(name, address, deviceId) {
    root.selectedName = name
    root.selectedAddress = address
    root.selectedDeviceId = deviceId || ""
    root.pairingPromptActive = false
    for (var i = 0; i < root.receivers.length; i++) {
      if (root.receivers[i].address === address) root.pairingRequired = !root.receivers[i].paired
    }
    saveProcess.command = [root.ctlPath, "save", name, address, root.selectedDeviceId]
    saveProcess.running = true
    root.checkPairing()
    root.injectPanel()
  }

  function clearSelection() {
    if (root.mirroring) root.stop()
    root.selectedName = ""
    root.selectedAddress = ""
    root.selectedDeviceId = ""
    root.pairingRequired = false
    root.pairingPromptActive = false
    clearProcess.command = [root.ctlPath, "clear"]
    clearProcess.running = true
    root.injectPanel()
  }

  function checkPairing() {
    if (root.selectedDeviceId === "") {
      root.pairingRequired = true
      root.injectPanel()
      return
    }
    pairingCheckProcess.command = [root.ctlPath, "paired", root.selectedDeviceId]
    pairingCheckProcess.running = true
  }

  function forgetReceiver(receiver) {
    if (!receiver || receiver.deviceId === "") {
      root.streamError = root.t("pairingCannotForget")
      root.injectPanel()
      return
    }
    if (root.mirroring && receiver.address === root.selectedAddress) root.stop()
    forgetProcess.command = [root.ctlPath, "forget", receiver.deviceId]
    forgetProcess.running = true
    if (receiver.address === root.selectedAddress) {
      root.pairingRequired = true
      root.pairingPromptActive = false
      root.injectPanel()
    }
  }

  function setReceiverPairing(address, paired) {
    var updated = []
    for (var i = 0; i < root.receivers.length; i++) {
      var receiver = root.receivers[i]
      updated.push({
        name: receiver.name,
        address: receiver.address,
        deviceId: receiver.deviceId,
        paired: receiver.address === address ? paired : receiver.paired
      })
    }
    root.receivers = updated
    if (root.selectedAddress === address) root.pairingRequired = !paired
    root.injectPanel()
  }

  function streamCommand(pairCode) {
    var command = ["env"]
    var vaapiDriver = String(root.setting("vaapiDriver", ""))
    if (vaapiDriver !== "") command.push("LIBVA_DRIVER_NAME=" + vaapiDriver)
    command.push(String(root.setting("doubletakePath", "doubletake")))
    command.push("-target", root.selectedAddress)
    command.push("-port-range", String(root.setting("portRange", "60000-60010")))
    command.push("-video-codec", String(root.setting("videoCodec", "h264")))
    command.push("-hwaccel", String(root.setting("hardwareEncoder", "auto")))
    command.push("-fps", String(root.setting("fps", 30)))
    command.push("-target-latency-ms", String(root.setting("targetLatencyMs", 180)))
    if (!root.boolSetting("audio", false)) command.push("-no-audio")
    if (pairCode !== "") command.push("-pair", "-code", pairCode)
    return command
  }

  function launchStream(pairCode) {
    root.streamError = ""
    root.deliberateStop = false
    mirrorProcess.command = root.streamCommand(pairCode || "")
    mirrorProcess.running = true
    root.notify(root.t("mirroringTitle"), root.t("connecting", { name: root.selectedName }))
    root.injectPanel()
    return "starting"
  }

  function start(pairCode) {
    if (root.mirroring) return "already-running"
    if (clearRestoreProcess.running) return "preparing-capture"
    if (root.selectedAddress === "") {
      root.open()
      return "no-receiver"
    }
    if ((pairCode || "") === "") root.pairingPromptActive = true
    root.pendingStartPairCode = pairCode || ""
    if (root.boolSetting("alwaysPromptForCapture", true) && root.selectedDeviceId !== "") {
      clearRestoreProcess.command = [root.ctlPath, "clear-restore", root.selectedDeviceId]
      clearRestoreProcess.running = true
      return "preparing-capture"
    }
    return root.launchStream(root.pendingStartPairCode)
  }

  function stop(silent) {
    if (!root.mirroring) return "stopped"
    root.deliberateStop = true
    mirrorProcess.running = false
    if (!silent) root.notify(root.t("mirroringTitle"), root.t("stopped", { name: root.selectedName }))
    root.injectPanel()
    return "stopping"
  }

  function pair(code) {
    var clean = String(code).replace(/\s/g, "")
    if (!/^\d{4}$/.test(clean)) return "invalid-code"
    root.setReceiverPairing(root.selectedAddress, true)
    root.pairingPromptActive = false
    root.pairingAttemptInFlight = true
    pairingCompleteTimer.restart()
    if (root.mirroring) {
      root.queuedPairCode = clean
      root.stop(true)
      return "restarting-for-pairing"
    }
    return root.start(clean)
  }

  function toggleStream() {
    if (root.mirroring) return root.stop()
    return root.start("")
  }

  Component.onCompleted: {
    loadProcess.command = [root.ctlPath, "load"]
    loadProcess.running = true
    root.discover()
  }

  onBarChanged: root.injectPanel()
  onSettingsChanged: root.injectPanel()

  Process {
    id: loadProcess
    property string outText: ""
    stdout: StdioCollector { waitForEnd: true; onStreamFinished: loadProcess.outText = text }
    onExited: function(code) {
      if (code === 0) {
        var fields = String(loadProcess.outText).trim().split("\t")
        if (fields.length >= 2) {
          root.selectedName = fields[0]
          root.selectedAddress = fields[1]
          root.selectedDeviceId = fields[2] || ""
          root.checkPairing()
        }
      }
      loadProcess.outText = ""
      root.injectPanel()
    }
  }

  Timer {
    id: pairingCompleteTimer
    interval: 8000
    repeat: false
    onTriggered: {
      root.pairingAttemptInFlight = false
      root.discover()
    }
  }

  Process {
    id: saveProcess
    stderr: StdioCollector { waitForEnd: true }
  }

  Process { id: clearProcess }

  Process {
    id: clearRestoreProcess
    property string errText: ""
    stderr: StdioCollector { waitForEnd: true; onStreamFinished: clearRestoreProcess.errText = text }
    onExited: function(code) {
      if (code === 0) root.launchStream(root.pendingStartPairCode)
      else {
        root.streamError = String(clearRestoreProcess.errText).trim() || root.t("capturePreparationFailed")
        root.injectPanel()
      }
      clearRestoreProcess.errText = ""
    }
  }

  Process {
    id: pairingCheckProcess
    onExited: function(code) {
      root.pairingRequired = code !== 0
      root.injectPanel()
    }
  }

  Process {
    id: forgetProcess
    property string errText: ""
    stderr: StdioCollector { waitForEnd: true; onStreamFinished: forgetProcess.errText = text }
    onExited: function(code) {
      if (code !== 0) root.streamError = String(forgetProcess.errText).trim() || root.t("pairingForgetFailed")
      else {
        root.notify(root.t("pairingForgottenTitle"), root.t("pairingForgotten"))
        root.discover()
      }
      forgetProcess.errText = ""
      root.injectPanel()
    }
  }

  Process {
    id: discoverProcess
    property string outText: ""
    property string errText: ""
    stdout: StdioCollector { waitForEnd: true; onStreamFinished: discoverProcess.outText = text }
    stderr: StdioCollector { waitForEnd: true; onStreamFinished: discoverProcess.errText = text }
    onExited: function(code) {
      if (code === 0) {
        root.receivers = root.parseReceivers(discoverProcess.outText)
        root.discoveryError = root.receivers.length === 0 ? root.t("noReceivers") : ""
      } else {
        root.receivers = []
        root.discoveryError = String(discoverProcess.errText).trim() || root.t("discoveryFailed")
      }
      discoverProcess.outText = ""
      discoverProcess.errText = ""
      root.injectPanel()
    }
  }

  Process {
    id: mirrorProcess
    property string errText: ""
    stderr: StdioCollector { waitForEnd: true; onStreamFinished: mirrorProcess.errText = text }
    onExited: function(code) {
      var wasDeliberate = root.deliberateStop
      root.deliberateStop = false
      if (root.queuedPairCode !== "") {
        var codeToUse = root.queuedPairCode
        root.queuedPairCode = ""
        Qt.callLater(function() { root.start(codeToUse) })
      } else if (!wasDeliberate && code !== 0) {
        if (root.pairingAttemptInFlight) {
          root.pairingAttemptInFlight = false
          pairingCompleteTimer.stop()
          root.setReceiverPairing(root.selectedAddress, false)
          root.pairingPromptActive = true
        }
        root.streamError = root.t("connectionFailed", { code: code })
        root.notify(root.t("connectionFailedTitle"), root.streamError)
      }
      mirrorProcess.errText = ""
      root.injectPanel()
    }
  }

  Loader {
    id: panelLoader
    active: true
    source: Qt.resolvedUrl("Panel.qml")
    visible: false
    onLoaded: {
      root.injectPanel()
      Qt.callLater(root.injectPanel)
    }
  }

  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  IpcHandler {
    target: "omarchy-airplay"
    function open(): void { root.open() }
    function close(): void { root.close() }
    function discover(): void { root.discover() }
    function select(name: string, address: string, deviceId: string): string {
      root.selectReceiver(name, address, deviceId)
      return "selected " + name + " (" + address + ")"
    }
    function unselect(): void { root.clearSelection() }
    function start(): string { return root.start("") }
    function stop(): string { return root.stop() }
    function toggle(): string { return root.toggleStream() }
    function pair(code: string): string { return root.pair(code) }
    function status(): string {
      if (root.mirroring) return "mirroring " + root.selectedName + " (" + root.selectedAddress + ")"
      if (root.selectedAddress !== "") return "stopped; selected " + root.selectedName + " (" + root.selectedAddress + ")"
      return "stopped; no receiver selected"
    }
  }

  BarIconButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    text: "󰐨"
    active: root.mirroring
    dimmed: !root.mirroring
    slotSize: Style.bar.statusSlot
    fontSize: Style.font.icon
    tooltipText: root.mirroring
      ? root.t("tooltipMirroring", { name: root.selectedName })
      : root.t("tooltipChoose")
    onPressed: function(mouseButton) {
      root.togglePanel()
    }
  }
}
