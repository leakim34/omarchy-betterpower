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
  readonly property var profiles: service ? service.profiles : []
  readonly property var profileOptions: Model.profileOptions(profiles)
  readonly property var settingsView: Model.normalizeSettings(root.settings, profiles)

  // Keyboard cursor: which source column and which chip inside its profile
  // group. -1 means the cursor is parked (mouse only).
  property int cursorSource: -1
  property int cursorIndex: 0
  readonly property bool cursorActive: cursorSource >= 0

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

  function setProfile(src, value) {
    if (service)
      service.setProfile(src, value);
  }

  function moveCursor(dx, dy) {
    if (!cursorActive) {
      cursorSource = Model.SOURCES.indexOf(source);
      cursorIndex = Math.max(0, profileOptions.map(function (o) {
        return o.value;
      }).indexOf(settingsView[Model.sourceKey(source, "profile")]));
      return;
    }
    if (dy !== 0)
      cursorSource = (cursorSource + (dy > 0 ? 1 : -1) + Model.SOURCES.length) % Model.SOURCES.length;
    if (dx !== 0)
      cursorIndex = (cursorIndex + (dx > 0 ? 1 : -1) + profileOptions.length) % profileOptions.length;
  }

  function activateCursor() {
    if (!cursorActive || cursorIndex < 0 || cursorIndex >= profileOptions.length)
      return;
    setProfile(Model.SOURCES[cursorSource], profileOptions[cursorIndex].value);
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
    function setProfile(source: string, profile: string): string {
      root.setProfile(source, profile);
      return root.statusJson();
    }
  }

  onSettingsChanged: if (service)
    service.updateSettings(root.settings)
  onOpenedChanged: {
    cursorSource = -1;
    if (opened && service)
      service.refreshProfiles();
  }

  KeyboardPanel {
    id: panel
    anchorItem: root.anchorItem
    owner: root.hostWidget || root
    bar: root.bar
    open: root.opened
    focusTarget: keyCatcher
    contentWidth: panel.fittedContentWidth(Style.space(400))
    contentHeight: panel.fittedContentHeight(column.implicitHeight)

    PanelKeyCatcher {
      id: keyCatcher
      anchors.fill: parent
      onMoveRequested: function (dx, dy) {
        root.moveCursor(dx, dy);
      }
      onActivateRequested: root.activateCursor()
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

        Repeater {
          model: Model.SOURCES
          Column {
            id: sourceSection
            required property var modelData
            required property int index
            readonly property string src: String(modelData)
            readonly property bool current: root.source === src
            readonly property string profileKey: Model.sourceKey(src, "profile")
            width: parent.width
            spacing: Style.spacing.rowGap

            PanelSeparator {
              visible: sourceSection.index > 0
              foreground: root.foreground
            }

            PanelSectionHeader {
              text: Model.sourceLabel(sourceSection.src).toUpperCase() + (sourceSection.current ? "  ·  NOW" : "")
              foreground: root.foreground
              fontFamily: root.fontFamily
            }

            Row {
              id: profileRow
              width: parent.width
              spacing: Style.spacing.md
              readonly property real cellWidth: root.profileOptions.length > 0 ? (width - spacing * (root.profileOptions.length - 1)) / root.profileOptions.length : 0

              Repeater {
                model: root.profileOptions
                Button {
                  required property var modelData
                  required property int index
                  width: profileRow.cellWidth
                  iconText: modelData.icon
                  iconSize: Style.font.title
                  text: modelData.label
                  fontSize: Style.font.bodySmall
                  foreground: root.foreground
                  fontFamily: root.fontFamily
                  horizontalPadding: Style.spacing.controlPaddingX
                  verticalPadding: Style.spacing.controlPaddingY + Style.spacing.xxs
                  bordered: true
                  active: root.settingsView[sourceSection.profileKey] === modelData.value
                  hasCursor: root.cursorSource === sourceSection.index && root.cursorIndex === index
                  onClicked: root.setProfile(sourceSection.src, modelData.value)
                  onHovered: function (h) {
                    if (h) {
                      root.cursorSource = sourceSection.index;
                      root.cursorIndex = index;
                    }
                  }
                }
              }
            }

            Text {
              textFormat: Text.PlainText
              width: parent.width
              wrapMode: Text.Wrap
              text: "Lock " + Model.delayLabel(root.settingsView[Model.sourceKey(sourceSection.src, "lock")]).toLowerCase() + " · sleep " + Model.delayLabel(Model.strategyFor(sourceSection.src, root.settingsView).sleep).toLowerCase()
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
