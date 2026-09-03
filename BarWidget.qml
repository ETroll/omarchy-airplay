import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui
import "i18n/I18n.js" as I18n

BarWidget {
  id: root
  moduleName: "io.github.etroll.omarchy-airplay"

  readonly property string ctlPath: String(Qt.resolvedUrl("bin/omarchy-airplay-run")).replace(/^file:\/\//, "")
  readonly property string runnerPath: ctlPath
  readonly property string localeName: Qt.locale().name

  property var receivers: []
  property string selectedName: ""
  property string selectedAddress: ""
  property string selectedDeviceId: ""
  property bool receiverAvailable: false
  property bool pairingRequired: false
  property bool pairingPromptActive: false
  property string discoveryError: ""
  property string streamError: ""
  property string networkDescription: ""
  property string firewallError: ""
  property bool firewallManaged: false
  property string forgettingAddress: ""
  property bool deliberateStop: false
  property string queuedPairCode: ""
  property string pendingStartPairCode: ""
  property bool pairingAttemptInFlight: false

  readonly property bool mirroring: mirrorProcess.running
  readonly property bool opened: panelLoader.item ? panelLoader.item.opened === true : false

  readonly property var mirroredProperties: [
    "bar", "settings", "receivers", "selectedName", "selectedAddress",
    "selectedDeviceId", "receiverAvailable", "pairingRequired", "pairingPromptActive", "discoveryError", "streamError", "mirroring",
    "networkDescription", "firewallError", "firewallManaged"
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
    root.refreshNetwork()
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
    root.receiverAvailable = true
    root.pairingPromptActive = false
    for (var i = 0; i < root.receivers.length; i++) {
      if (root.receivers[i].address === address) root.pairingRequired = !root.receivers[i].paired
    }
    saveProcess.command = [root.ctlPath, "save", name, address, root.selectedDeviceId]
    saveProcess.running = true
    root.checkPairing()
    root.refreshFirewallState()
    root.injectPanel()
  }

  function refreshNetwork() {
    networkProcess.command = [root.ctlPath, "network"]
    networkProcess.running = true
  }

  function refreshFirewallState() {
    root.firewallManaged = false
    root.firewallError = ""
    if (root.selectedDeviceId === "") { root.injectPanel(); return }
    firewallLoadProcess.command = [root.ctlPath, "firewall-load", root.selectedDeviceId]
    firewallLoadProcess.running = true
  }

  function allowSelectedReceiver() {
    if (root.selectedDeviceId === "" || root.selectedAddress === "") return "no-receiver"
    root.firewallError = ""
    firewallAllowProcess.command = [root.runnerPath, "--timeout", "120", "--", "pkexec", "/usr/bin/ufw", "allow", "from", root.selectedAddress,
      "to", "any", "port", String(root.setting("portRange", "60000-60010")).replace("-", ":"), "proto", "udp"]
    firewallAllowProcess.running = true
    root.injectPanel()
    return "authorizing-firewall"
  }

  function clearSelection() {
    if (root.mirroring) root.stop()
    root.selectedName = ""
    root.selectedAddress = ""
    root.selectedDeviceId = ""
    root.receiverAvailable = false
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
    root.forgettingAddress = receiver.address
    pendingForgetReceiver = receiver
    firewallLookupForForgetProcess.command = [root.ctlPath, "firewall-load", receiver.deviceId]
    firewallLookupForForgetProcess.running = true
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
    var executable = String(root.setting("doubletakePath", "doubletake"))
    var portRange = String(root.setting("portRange", "60000-60010"))
    var codec = String(root.setting("videoCodec", "h264"))
    var encoder = String(root.setting("hardwareEncoder", "auto"))
    var fps = Number(root.setting("fps", 30))
    var latency = Number(root.setting("targetLatencyMs", 180))
    if (!(executable === "doubletake" || /^\/[A-Za-z0-9._/-]*\/doubletake$/.test(executable))) return null
    if (!/^\d{1,5}-\d{1,5}$/.test(portRange) || ["h264", "hevc", "auto"].indexOf(codec) < 0 ||
        ["auto", "vaapi", "nvenc", "openh264", "none"].indexOf(encoder) < 0 || fps < 15 || fps > 60 || latency < 0 || latency > 1000) return null
    var command = ["env"]
    var vaapiDriver = String(root.setting("vaapiDriver", ""))
    if (vaapiDriver !== "") command.push("LIBVA_DRIVER_NAME=" + vaapiDriver)
    if (pairCode !== "") command.push("DOUBLETAKE_CODE=" + pairCode)
    command.push(executable)
    command.push("-target", root.selectedAddress)
    command.push("-port-range", portRange, "-video-codec", codec, "-hwaccel", encoder, "-fps", String(fps), "-target-latency-ms", String(latency))
    if (!root.boolSetting("audio", false)) command.push("-no-audio")
    if (pairCode !== "") command.push("-pair")
    return [root.runnerPath, "--timeout", "120", "--"].concat(command)
  }

  function launchStream(pairCode) {
    root.streamError = ""
    root.deliberateStop = false
    var command = root.streamCommand(pairCode || "")
    if (command === null) { root.streamError = "Invalid DoubleTake settings"; root.injectPanel(); return "invalid-settings" }
    mirrorProcess.command = command
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
    var clean = String(code)
    if (clean.length < 1 || clean.length > 128 || /[\u0000-\u001f\u007f]/.test(clean)) return "invalid-code"
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
    root.refreshNetwork()
  }

  Component.onDestruction: {
    loadProcess.running = false; networkProcess.running = false; firewallLoadProcess.running = false
    firewallAllowProcess.running = false; firewallLookupForForgetProcess.running = false; firewallRemoveProcess.running = false
    saveProcess.running = false; clearProcess.running = false; clearRestoreProcess.running = false
    pairingCheckProcess.running = false; forgetProcess.running = false; discoverProcess.running = false; mirrorProcess.running = false
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
          root.receiverAvailable = false
          root.checkPairing()
        }
      }
      loadProcess.outText = ""
      root.injectPanel()
    }
  }

  property var pendingForgetReceiver: null

  function finishForget() {
    if (!pendingForgetReceiver) return
    forgetProcess.command = [root.ctlPath, "forget", pendingForgetReceiver.deviceId]
    forgetProcess.running = true
    pendingForgetReceiver = null
  }

  Process {
    id: networkProcess
    property string outText: ""
    stdout: StdioCollector { waitForEnd: true; onStreamFinished: networkProcess.outText = text }
    onExited: function(code) {
      if (code === 0) {
        var fields = String(networkProcess.outText).trim().split("\t")
        root.networkDescription = fields.length >= 4
          ? ((fields[1] || fields[0]) + " · " + (fields[2] || fields[0]) + " · " + fields[3]) : ""
      } else root.networkDescription = ""
      networkProcess.outText = ""
      root.injectPanel()
    }
  }

  Process {
    id: firewallLoadProcess
    property string outText: ""
    stdout: StdioCollector { waitForEnd: true; onStreamFinished: firewallLoadProcess.outText = text }
    onExited: function(code) {
      var fields = String(firewallLoadProcess.outText).trim().split("\t")
      root.firewallManaged = code === 0 && fields.length >= 3 && fields[1] === root.selectedAddress
      firewallLoadProcess.outText = ""
      root.injectPanel()
    }
  }

  Process {
    id: firewallAllowProcess
    property string errText: ""
    stderr: StdioCollector { waitForEnd: true; onStreamFinished: firewallAllowProcess.errText = text }
    onExited: function(code) {
      if (code === 0) {
        firewallSaveProcess.command = [root.ctlPath, "firewall-save", root.selectedDeviceId, root.selectedAddress,
          String(root.setting("portRange", "60000-60010"))]
        firewallSaveProcess.running = true
        root.firewallManaged = true
        root.notify(root.t("firewallAllowedTitle"), root.t("firewallAllowed", { address: root.selectedAddress }))
      } else root.firewallError = root.t("firewallAllowFailed")
      firewallAllowProcess.errText = ""
      root.injectPanel()
    }
  }

  Process { id: firewallSaveProcess }

  Process {
    id: firewallLookupForForgetProcess
    property string outText: ""
    stdout: StdioCollector { waitForEnd: true; onStreamFinished: firewallLookupForForgetProcess.outText = text }
    onExited: function(code) {
      var fields = String(firewallLookupForForgetProcess.outText).trim().split("\t")
      firewallLookupForForgetProcess.outText = ""
      if (code !== 0 || fields.length < 3) { root.finishForget(); return }
      firewallRemoveProcess.command = [root.runnerPath, "--timeout", "120", "--", "pkexec", "/usr/bin/ufw", "--force", "delete", "allow", "from", fields[1],
        "to", "any", "port", String(fields[2]).replace("-", ":"), "proto", "udp"]
      firewallRemoveProcess.running = true
    }
  }

  Process {
    id: firewallRemoveProcess
    onExited: function(code) {
      if (code === 0 && pendingForgetReceiver) {
        if (pendingForgetReceiver.address === root.selectedAddress) root.firewallManaged = false
        firewallClearProcess.command = [root.ctlPath, "firewall-clear", pendingForgetReceiver.deviceId]
        firewallClearProcess.running = true
        root.finishForget()
      } else {
        root.firewallError = root.t("firewallRemoveFailed")
        pendingForgetReceiver = null
      }
      root.injectPanel()
    }
  }

  Process { id: firewallClearProcess }

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
        if (root.forgettingAddress === root.selectedAddress) root.firewallManaged = false
        root.notify(root.t("pairingForgottenTitle"), root.t("pairingForgotten"))
        root.discover()
      }
      root.forgettingAddress = ""
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
        root.receiverAvailable = root.selectedAddress !== "" && root.receivers.some(function(receiver) {
          return receiver.address === root.selectedAddress
        })
        root.discoveryError = root.receivers.length === 0 ? root.t("noReceivers") : ""
      } else {
        root.receivers = []
        root.receiverAvailable = false
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
        var errorText = String(mirrorProcess.errText)
        var credentialRequired = /password cannot be empty|configured password|pin|pairing code/i.test(errorText)
        if (credentialRequired) {
          root.pairingRequired = true
          root.pairingPromptActive = true
        }
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
    target: "io.github.etroll.omarchy-airplay"
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
