import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.UPower
import qs.Commons
import qs.Ui
import "Model.js" as Model

// The leakz.power popup. Reads state from the service, calls its functions,
// and never computes policy or touches the system itself.
Panel {
  id: root
  moduleName: "leakz.power"
  ipcTarget: "leakz.power"
  // The single IpcHandler for this target lives here so it can expose status
  // from the service next to open/close.
  manageIpc: false

  property var anchorItem: null
  property var hostWidget: null

  readonly property var service: bar && bar.shell && typeof bar.shell.serviceFor === "function" ? bar.shell.serviceFor("leakz.power") : null
  readonly property color foreground: bar ? bar.foreground : Color.foreground
  readonly property string fontFamily: bar ? bar.fontFamily : Style.font.family
  readonly property var device: UPower.displayDevice
  readonly property bool batteryPresent: !!(device && device.isPresent)
  readonly property string source: UPower.onBattery ? "battery" : "ac"
  readonly property int percentage: batteryPresent ? Math.round(Number(device.percentage || 0) * 100) : -1
  readonly property var settingsView: Model.normalizeSettings(root.settings, [])

  readonly property string heroMeta: {
    if (!batteryPresent)
      return "NO BATTERY";
    var s = Model.sourceLabel(source).toUpperCase();
    return s + " · " + percentage + "%";
  }

  function statusJson() {
    return service ? service.statusJson() : JSON.stringify({
      service: "not loaded"
    });
  }

  IpcHandler {
    target: "leakz.power"

    function open(): void {
      root.open();
    }
    function close(): void {
      root.close();
    }
    function show(): void {
      root.open();
    }
    function hide(): void {
      root.close();
    }
    function toggle(): void {
      root.toggle();
    }
    function status(): string {
      return root.statusJson();
    }
  }

  onSettingsChanged: if (service)
    service.updateSettings(root.settings)

  KeyboardPanel {
    id: panel
    anchorItem: root.anchorItem
    owner: root.hostWidget || root
    bar: root.bar
    open: root.opened
    focusTarget: keyCatcher
    contentWidth: panel.fittedContentWidth(Style.space(420))
    contentHeight: panel.fittedContentHeight(column.implicitHeight)

    PanelKeyCatcher {
      id: keyCatcher
      anchors.fill: parent
      onCloseRequested: root.close()
      onTabRequested: function (direction) {
        root.switchPanel(direction);
      }

      Column {
        id: column
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        spacing: Style.spacing.panelGap

        PanelHero {
          width: parent.width
          title: "Power"
          meta: root.heroMeta
          foreground: root.foreground
          fontFamily: root.fontFamily
          iconComponent: Component {
            Text {
              textFormat: Text.PlainText
              text: root.hostWidget && typeof root.hostWidget.icon === "function" ? root.hostWidget.icon() : "󰚥"
              color: root.foreground
              font.family: root.fontFamily
              font.pixelSize: Style.font.display
            }
          }
        }

        PanelSeparator {
          foreground: root.foreground
        }

        Row {
          width: parent.width
          spacing: Style.spacing.panelGap

          Repeater {
            model: Model.SOURCES
            Column {
              required property var modelData
              readonly property string src: String(modelData)
              readonly property bool current: root.source === src
              width: (parent.width - parent.spacing) / 2
              spacing: Style.spacing.labelGap

              PanelSectionHeader {
                text: Model.sourceLabel(src).toUpperCase() + (current ? "  ·  NOW" : "")
                foreground: root.foreground
                fontFamily: root.fontFamily
              }

              Text {
                textFormat: Text.PlainText
                width: parent.width
                wrapMode: Text.Wrap
                text: Model.profileLabel(root.settingsView[Model.sourceKey(src, "profile")]) + " · lock " + Model.delayLabel(root.settingsView[Model.sourceKey(src, "lock")]).toLowerCase() + " · sleep " + Model.delayLabel(Model.strategyFor(src, root.settingsView).sleep).toLowerCase()
                color: root.foreground
                opacity: 0.7
                font.family: root.fontFamily
                font.pixelSize: Style.font.bodySmall
              }
            }
          }
        }
      }
    }
  }
}
