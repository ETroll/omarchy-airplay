import QtQuick
import QtQuick.Controls
import Quickshell
import qs.Commons
import qs.Ui

Panel {
  id: root
  moduleName: "omarchy-airplay"

  property var anchorItem: null
  property var hostWidget: null
  readonly property var barIdentity: hostWidget || root

  property var receivers: []
  property string selectedName: ""
  property string selectedAddress: ""
  property string selectedDeviceId: ""
  property bool pairingRequired: false
  property string discoveryError: ""
  property string streamError: ""
  property bool mirroring: false

  readonly property color foreground: bar ? bar.foreground : Color.foreground
  readonly property color dim: Qt.darker(foreground, 1.45)
  readonly property string fontFamily: bar ? bar.fontFamily : Style.font.family

  function open() {
    root.controller.show()
    Qt.callLater(function() { if (root.opened) keyCatcher.forceActiveFocus() })
  }

  function close() { root.controller.hide() }
  function toggle() { if (root.opened) root.close(); else root.open() }

  KeyboardPanel {
    id: panel
    anchorItem: root.anchorItem
    owner: root.barIdentity
    bar: root.bar
    open: root.opened
    focusTarget: keyCatcher
    contentWidth: panel.fittedContentWidth(Style.space(400))
    contentHeight: panel.fittedContentHeight(contentColumn.implicitHeight, Style.space(620))

    PanelKeyCatcher {
      id: keyCatcher
      anchors.fill: parent
      onCloseRequested: root.close()

      Flickable {
        anchors.fill: parent
        contentWidth: width
        contentHeight: contentColumn.implicitHeight
        clip: true
        boundsBehavior: Flickable.StopAtBounds

        ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }

        Column {
          id: contentColumn
          width: parent.width
          spacing: Style.spacing.panelGap

          PanelHero {
            title: "AirPlay Mirror"
            meta: root.mirroring
              ? "Mirroring to " + root.selectedName
              : (root.selectedAddress !== "" ? "Ready for " + root.selectedName : "Choose a receiver")
            foreground: root.foreground
            fontFamily: root.fontFamily

            iconComponent: Component {
              Text {
                text: "󰐨"
                color: root.mirroring ? Color.accent : root.foreground
                font.family: root.fontFamily
                font.pixelSize: Style.font.display
              }
            }

            trailingControl: Component {
              PanelActionButton {
                iconText: "󰑐"
                tooltipText: "Discover receivers"
                foreground: root.foreground
                hoverColor: Color.accent
                fontFamily: root.fontFamily
                onClicked: if (root.hostWidget) root.hostWidget.discover()
              }
            }
          }

          Text {
            visible: root.streamError !== ""
            width: parent.width
            text: root.streamError
            color: Color.urgent
            font.family: root.fontFamily
            font.pixelSize: Style.font.caption
            wrapMode: Text.WordWrap
          }

          PanelSeparator { foreground: root.foreground }

          PanelSectionHeader {
            text: "RECEIVERS"
            foreground: root.foreground
            fontFamily: root.fontFamily
          }

          Text {
            visible: root.discoveryError !== ""
            width: parent.width
            text: root.discoveryError
            color: root.discoveryError === "No AirPlay receivers found" ? root.dim : Color.urgent
            font.family: root.fontFamily
            font.pixelSize: Style.font.caption
            wrapMode: Text.WordWrap
          }

          Repeater {
            model: root.receivers

            delegate: Rectangle {
              id: receiverRow
              required property var modelData
              readonly property bool selected: modelData.address === root.selectedAddress

              width: contentColumn.width
              implicitHeight: receiverContent.implicitHeight + Style.spacing.lg * 2
              radius: Style.cornerRadius
              color: selected ? Style.hoverFillFor(Color.accent, root.foreground) : "transparent"
              border.width: selected ? 1 : 0
              border.color: selected ? Color.accent : "transparent"

              Row {
                id: receiverContent
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                anchors.leftMargin: Style.spacing.rowPaddingX
                anchors.rightMargin: Style.spacing.rowPaddingX
                spacing: Style.spacing.lg

                Text {
                  text: receiverRow.selected ? "󰄬" : "󰐨"
                  color: receiverRow.selected ? Color.accent : root.dim
                  font.family: root.fontFamily
                  font.pixelSize: Style.font.icon
                  anchors.verticalCenter: parent.verticalCenter
                }

                Column {
                  width: parent.width - actionRow.width - Style.space(60)
                  spacing: Style.spacing.xxs

                  Text {
                    width: parent.width
                    text: receiverRow.modelData.name
                    color: root.foreground
                    font.family: root.fontFamily
                    font.pixelSize: Style.font.body
                    font.bold: true
                    elide: Text.ElideRight
                  }

                  Text {
                    width: parent.width
                    text: receiverRow.modelData.address
                    color: root.dim
                    font.family: root.fontFamily
                    font.pixelSize: Style.font.caption
                    elide: Text.ElideRight
                  }
                }

                Row {
                  id: actionRow
                  spacing: Style.spacing.xs
                  anchors.verticalCenter: parent.verticalCenter

                  Button {
                    text: root.mirroring && receiverRow.selected ? "Stopp" : "Speil"
                    onClicked: {
                      if (!root.hostWidget) return
                      if (root.mirroring && receiverRow.selected) root.hostWidget.stop()
                      else {
                        root.hostWidget.selectReceiver(receiverRow.modelData.name, receiverRow.modelData.address, receiverRow.modelData.deviceId)
                        root.hostWidget.start("")
                      }
                    }
                  }

                  Button {
                    text: receiverRow.selected ? "Fjern valg" : "Velg"
                    onClicked: {
                      if (!root.hostWidget) return
                      if (receiverRow.selected) root.hostWidget.clearSelection()
                      else root.hostWidget.selectReceiver(receiverRow.modelData.name, receiverRow.modelData.address, receiverRow.modelData.deviceId)
                    }
                  }

                  Button {
                    text: "Glem"
                    enabled: receiverRow.modelData.deviceId !== ""
                    onClicked: if (root.hostWidget) root.hostWidget.forgetReceiver(receiverRow.modelData)
                  }
                }
              }
            }
          }

          PanelSectionHeader {
            visible: root.selectedAddress !== "" && root.pairingRequired
            text: "PAIR A NEW RECEIVER"
            foreground: root.foreground
            fontFamily: root.fontFamily
          }

          Text {
            visible: root.selectedAddress !== "" && root.pairingRequired
            width: parent.width
            text: "Select the receiver and start once to make its PIN appear. Enter that four-digit PIN here."
            color: root.dim
            font.family: root.fontFamily
            font.pixelSize: Style.font.caption
            wrapMode: Text.WordWrap
          }

          Row {
            visible: root.selectedAddress !== "" && root.pairingRequired
            width: parent.width
            spacing: Style.spacing.sm

            TextField {
              id: pairingCode
              width: Style.space(120)
              placeholderText: "PIN"
              maximumLength: 4
              inputMethodHints: Qt.ImhDigitsOnly
              validator: RegularExpressionValidator { regularExpression: /\d{0,4}/ }
              onAccepted: pairButton.clicked()
            }

            Button {
              id: pairButton
              text: "Pair & connect"
              enabled: root.selectedAddress !== "" && pairingCode.text.length === 4
              onClicked: {
                if (root.hostWidget) root.hostWidget.pair(pairingCode.text)
                pairingCode.text = ""
              }
            }
          }

          Text {
            width: parent.width
            text: "Click the AirPlay icon in the bar to open this receiver list."
            color: root.dim
            font.family: root.fontFamily
            font.pixelSize: Style.font.caption
            wrapMode: Text.WordWrap
          }
        }
      }
    }
  }
}
