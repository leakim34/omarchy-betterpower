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

  // Keyboard cursor over a grid: each source owns two rows, its profile
  // buttons then its delay dropdowns. -1 means the cursor is parked.
  readonly property int rowsPerSource: 2
  property int cursorRow: -1
  property int cursorIndex: 0
  readonly property bool cursorActive: cursorRow >= 0
  readonly property int cursorSource: cursorActive ? Math.floor(cursorRow / rowsPerSource) : -1
  readonly property int cursorKind: cursorActive ? cursorRow % rowsPerSource : -1
  readonly property var delayFields: ["screensaver", "lock"]
  property var delayControls: ({})

  function registerDelayControl(sourceIndex, fieldIndex, item) {
    var next = {};
    for (var k in delayControls)
      next[k] = delayControls[k];
    next[sourceIndex + ":" + fieldIndex] = item;
    delayControls = next;
  }

  function rowLength(row) {
    return row % rowsPerSource === 0 ? profileOptions.length : delayFields.length;
  }

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

  function setDelay(src, field, seconds) {
    if (service)
      service.setDelay(src, field, seconds);
  }

  function moveCursor(dx, dy) {
    var rows = Model.SOURCES.length * rowsPerSource;
    if (!cursorActive) {
      cursorRow = Model.SOURCES.indexOf(source) * rowsPerSource;
      cursorIndex = Math.max(0, profileOptions.map(function (o) {
        return o.value;
      }).indexOf(settingsView[Model.sourceKey(source, "profile")]));
      return;
    }
    if (dy !== 0)
      cursorRow = (cursorRow + (dy > 0 ? 1 : -1) + rows) % rows;
    var len = rowLength(cursorRow);
    if (dx !== 0)
      cursorIndex = (cursorIndex + (dx > 0 ? 1 : -1) + len) % len;
    cursorIndex = Math.min(cursorIndex, len - 1);
  }

  function activateCursor() {
    if (!cursorActive)
      return;
    if (cursorKind === 0) {
      if (cursorIndex < profileOptions.length)
        setProfile(Model.SOURCES[cursorSource], profileOptions[cursorIndex].value);
      return;
    }
    var control = delayControls[cursorSource + ":" + cursorIndex];
    if (control && typeof control.open === "function")
      control.open();
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
    function setDelay(source: string, field: string, seconds: string): string {
      root.setDelay(source, field, seconds);
      return root.statusJson();
    }
  }

  onOpenedChanged: {
    cursorRow = -1;
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

            Row {
              id: delayRow
              width: parent.width
              spacing: Style.spacing.md
              readonly property real cellWidth: (width - spacing * (root.delayFields.length - 1)) / root.delayFields.length

              Repeater {
                model: root.delayFields
                Dropdown {
                  id: delayDropdown
                  required property var modelData
                  required property int index
                  readonly property string field: String(modelData)
                  readonly property string key: Model.sourceKey(sourceSection.src, field)
                  width: delayRow.cellWidth
                  label: field === "screensaver" ? "Screensaver after" : "Lock after"
                  options: Model.delayOptions(root.settingsView[key])
                  value: String(root.settingsView[key])
                  foreground: root.foreground
                  accent: Color.accent
                  fontFamily: root.fontFamily
                  hasCursor: root.cursorSource === sourceSection.index && root.cursorKind === 1 && root.cursorIndex === index
                  onChanged: function (v) {
                    root.setDelay(sourceSection.src, field, v);
                  }
                  onHovered: function (h) {
                    if (h) {
                      root.cursorRow = sourceSection.index * root.rowsPerSource + 1;
                      root.cursorIndex = index;
                    }
                  }
                  Component.onCompleted: root.registerDelayControl(sourceSection.index, index, delayDropdown)
                }
              }
            }
          }
        }
      }
    }
  }
}
