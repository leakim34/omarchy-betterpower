import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.UPower
import qs.Commons
import qs.Ui
import "Model.js" as Model

// The leakz.betterpower popup. Reads state from the service, calls its functions,
// and never computes policy or touches the system itself.
Panel {
  id: root
  moduleName: "leakz.betterpower"
  ipcTarget: "leakz.betterpower"
  // The single IpcHandler for this target lives here so it can expose status
  // from the service next to open/close.
  manageIpc: false

  property var anchorItem: null
  property var hostWidget: null

  readonly property var service: bar && bar.shell && typeof bar.shell.serviceFor === "function" ? bar.shell.serviceFor("leakz.betterpower") : null
  readonly property color foreground: bar ? bar.foreground : Color.foreground
  readonly property string fontFamily: bar ? bar.fontFamily : Style.font.family
  readonly property var device: UPower.displayDevice
  readonly property bool batteryPresent: !!(device && device.isPresent)
  readonly property string source: UPower.onBattery ? "battery" : "ac"
  readonly property int percentage: batteryPresent ? Math.round(Number(device.percentage || 0) * 100) : -1
  readonly property var upowerStates: ({
      Charging: UPowerDeviceState.Charging,
      Discharging: UPowerDeviceState.Discharging,
      FullyCharged: UPowerDeviceState.FullyCharged,
      PendingCharge: UPowerDeviceState.PendingCharge
    })
  readonly property bool onBattery: UPower.onBattery
  readonly property real batteryFraction: Model.batteryFraction(device)
  readonly property bool chargeThresholdActive: Model.chargeThresholdActive(device, onBattery, upowerStates)
  readonly property bool fullyCharged: batteryPresent && device.state === UPowerDeviceState.FullyCharged && !chargeThresholdActive
  readonly property bool batteryFull: fullyCharged || (!onBattery && batteryFraction >= 1)
  readonly property bool charging: batteryPresent && !onBattery && !batteryFull && !chargeThresholdActive
  readonly property string batteryIcon: Model.batteryIcon(device, onBattery, upowerStates)
  readonly property string modeLabel: Model.modeLabel(device, onBattery, upowerStates)

  // Stats from omarchy-battery-status, refreshed while the panel is open.
  property var batteryInfo: ({})
  property int phraseIndex: 0
  readonly property var activePhrases: fullyCharged ? [] : (charging ? Model.CHARGING_PHRASES : (onBattery && batteryPresent ? Model.ON_BATTERY_PHRASES : []))
  readonly property bool rotatingPhrases: activePhrases.length > 0
  readonly property string heroStatusText: fullyCharged ? "Fully charged" : (rotatingPhrases ? activePhrases[phraseIndex % activePhrases.length] : modeLabel)
  readonly property string chargeLimitText: Model.chargeLimitLabel(service ? service.chargeState : null, batteryInfo.threshold || "")

  function updateBatteryInfo(raw) {
    var next = Model.parseKeyValue(raw);
    // Keep last known good data across a transient empty read (plug events).
    if (Object.keys(next).length === 0)
      return;
    batteryInfo = next;
  }

  Process {
    id: batteryProc
    command: ["omarchy-battery-status", "--shell"]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: root.updateBatteryInfo(text)
    }
  }

  function refreshBattery() {
    if (batteryPresent && !batteryProc.running)
      batteryProc.running = true;
  }

  Timer {
    interval: 5000
    running: root.opened
    repeat: true
    onTriggered: root.refreshBattery()
  }

  Timer {
    interval: 2800
    running: root.opened && root.rotatingPhrases
    repeat: true
    onTriggered: phraseSwap.restart()
  }

  SequentialAnimation {
    id: phraseSwap
    PropertyAnimation {
      target: heroStatus
      property: "opacity"
      to: 0.0
      duration: 180
      easing.type: Easing.OutQuad
    }
    ScriptAction {
      script: {
        var n = root.activePhrases.length;
        if (n > 0)
          root.phraseIndex = (root.phraseIndex + 1) % n;
      }
    }
    PropertyAnimation {
      target: heroStatus
      property: "opacity"
      to: 1.0
      duration: 260
      easing.type: Easing.InQuad
    }
  }

  onRotatingPhrasesChanged: {
    if (!rotatingPhrases) {
      phraseSwap.stop();
      heroStatus.opacity = 1.0;
    }
  }
  readonly property var profiles: service ? service.profiles : []
  readonly property var profileOptions: Model.profileOptions(profiles)
  readonly property var settingsView: Model.normalizeSettings(root.settings, profiles)

  readonly property var chargeCapability: service ? service.chargeCapability : Model.chargeCapability(null)
  readonly property bool chargeLimitEnabled: service ? service.chargeLimitEnabled : false
  readonly property bool chargeBusy: service ? service.chargeBusy : false
  readonly property bool externalScreen: service ? service.externalScreen : false
  readonly property var lidBehavior: service ? service.lidBehavior : Model.lidBehavior(false, false)

  // Keyboard cursor over a grid. Row 0 is the protection toggle (when shown),
  // then each source owns two rows: profile buttons, delay dropdowns.
  // -1 means the cursor is parked.
  readonly property int rowsPerSource: 2
  // Head controls in order: charge toggle when available, then clamshell.
  readonly property var headKeys: {
    var keys = [];
    if (chargeCapability.available)
      keys.push("charge");
    keys.push("clamshell");
    return keys;
  }
  readonly property int headRows: headKeys.length
  property int cursorRow: -1
  property int cursorIndex: 0
  readonly property bool cursorActive: cursorRow >= 0
  readonly property string cursorHead: cursorActive && cursorRow < headRows ? headKeys[cursorRow] : ""
  readonly property bool cursorOnCharge: cursorHead === "charge"
  readonly property bool cursorOnClamshell: cursorHead === "clamshell"
  readonly property int cursorSource: cursorActive && !cursorOnCharge ? Math.floor((cursorRow - headRows) / rowsPerSource) : -1
  readonly property int cursorKind: cursorActive && !cursorOnCharge ? (cursorRow - headRows) % rowsPerSource : -1
  readonly property var delayFields: ["screensaver", "lock", "sleep"]
  property var delayControls: ({})

  function registerDelayControl(sourceIndex, fieldIndex, item) {
    var next = {};
    for (var k in delayControls)
      next[k] = delayControls[k];
    next[sourceIndex + ":" + fieldIndex] = item;
    delayControls = next;
  }

  function rowLength(row) {
    if (row < headRows)
      return 1;
    return (row - headRows) % rowsPerSource === 0 ? profileOptions.length : delayFields.length;
  }

  function setChargeLimit(enabled) {
    if (service)
      service.setChargeLimit(enabled);
  }

  function setClamshell(enabled) {
    if (service)
      service.setClamshell(enabled);
  }

  readonly property string heroMeta: {
    if (!batteryPresent)
      return "NO BATTERY";
    var s = Model.sourceLabel(source).toUpperCase();
    return s + " · " + percentage + "%";
  }

  function statusJson() {
    var status = service ? JSON.parse(service.statusJson()) : {
      service: "not loaded"
    };
    status.opened = root.opened;
    status.cursor = {
      row: root.cursorRow,
      index: root.cursorIndex
    };
    return JSON.stringify(status);
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
    var rows = headRows + Model.SOURCES.length * rowsPerSource;
    if (!cursorActive) {
      cursorRow = headRows + Model.SOURCES.indexOf(source) * rowsPerSource;
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
    if (cursorOnCharge) {
      setChargeLimit(!chargeLimitEnabled);
      return;
    }
    if (cursorOnClamshell) {
      if (externalScreen)
        setClamshell(!settingsView.clamshell);
      return;
    }
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
    target: "leakz.betterpower"

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
    function setChargeLimit(enabled: string): string {
      root.setChargeLimit(enabled === "true");
      return root.statusJson();
    }
    function togglePercentage(): string {
      if (root.service)
        root.service.setShowPercentage(!root.settingsView.showPercentage);
      return root.statusJson();
    }
    function setClamshell(enabled: string): string {
      root.setClamshell(enabled === "true");
      return root.statusJson();
    }
  }

  onOpenedChanged: {
    cursorRow = -1;
    if (opened) {
      refreshBattery();
      if (service) {
        service.refreshProfiles();
        service.refreshCharge();
      }
    }
  }

  KeyboardPanel {
    id: panel
    anchorItem: root.anchorItem
    owner: root.hostWidget || root
    bar: root.bar
    open: root.opened
    focusTarget: keyCatcher
    contentWidth: panel.fittedContentWidth(Style.space(440))
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

        // ---------- Hero: battery icon · title/status · percentage ----------
        Item {
          width: parent.width
          implicitHeight: Math.max(heroIcon.implicitHeight, heroLabels.implicitHeight, heroPercent.implicitHeight)

          Text {
            id: heroIcon
            textFormat: Text.PlainText
            text: root.batteryIcon
            color: root.foreground
            font.family: root.fontFamily
            font.pixelSize: Style.font.display
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            Behavior on color {
              ColorAnimation {
                duration: 200
              }
            }
          }

          Column {
            id: heroLabels
            anchors.left: heroIcon.right
            anchors.leftMargin: Style.spacing.xxxl
            anchors.right: heroPercent.left
            anchors.rightMargin: Style.spacing.xl
            anchors.verticalCenter: parent.verticalCenter
            spacing: Style.spacing.xxs

            Text {
              text: "Battery"
              color: root.foreground
              font.family: root.fontFamily
              font.pixelSize: Style.font.title
              font.bold: true
              elide: Text.ElideRight
              width: parent.width
            }

            Text {
              id: heroStatus
              textFormat: Text.PlainText
              text: root.heroStatusText.toUpperCase()
              color: Qt.darker(root.foreground, 1.4)
              font.family: root.fontFamily
              font.pixelSize: Style.font.caption
              font.bold: true
              font.letterSpacing: 1.2
              elide: Text.ElideRight
              width: parent.width
            }
          }

          Text {
            id: heroPercent
            textFormat: Text.PlainText
            text: root.batteryPresent ? root.percentage + "%" : "—"
            color: root.foreground
            font.family: root.fontFamily
            font.pixelSize: Style.font.displayLarge
            font.bold: true
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
          }
        }

        // ---------- Battery progress bar ----------
        Item {
          width: parent.width
          implicitHeight: Style.spacing.lg

          Rectangle {
            id: barTrack
            anchors.fill: parent
            radius: height / 2
            color: Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, 0.12)
          }

          Rectangle {
            anchors.left: barTrack.left
            anchors.verticalCenter: barTrack.verticalCenter
            height: barTrack.height
            radius: barTrack.radius
            color: root.foreground
            width: Math.max(barTrack.height, barTrack.width * root.batteryFraction)
            Behavior on width {
              NumberAnimation {
                duration: 320
                easing.type: Easing.OutCubic
              }
            }
            // Subtle pulse while charging: energy is flowing in.
            SequentialAnimation on opacity {
              running: root.charging && root.opened
              loops: Animation.Infinite
              alwaysRunToEnd: true
              NumberAnimation {
                from: 1.0
                to: 0.55
                duration: 950
                easing.type: Easing.InOutSine
              }
              NumberAnimation {
                from: 0.55
                to: 1.0
                duration: 950
                easing.type: Easing.InOutSine
              }
            }
          }
        }

        // ---------- Stats ----------
        Row {
          visible: root.batteryInfo.percentage !== undefined
          width: parent.width
          spacing: Style.spacing.huge

          Column {
            width: (parent.width - parent.spacing) / 2
            spacing: Style.spacing.labelGap
            InfoPair {
              label: "Battery size"
              value: root.batteryInfo.size || ""
            }
            InfoPair {
              label: "Charge cycles"
              value: root.batteryInfo.cycles || "—"
            }
          }

          Column {
            width: (parent.width - parent.spacing) / 2
            spacing: Style.spacing.labelGap
            InfoPair {
              label: root.chargeThresholdActive ? "Charge limit" : (root.onBattery ? "Time left" : "Time to full")
              value: root.chargeThresholdActive ? root.chargeLimitText : (root.batteryFull ? "-" : (root.batteryInfo.time || "—"))
            }
            InfoPair {
              label: root.chargeThresholdActive ? "Battery state" : (root.onBattery ? "Discharging" : "Charging")
              value: root.chargeThresholdActive ? "Holding" : (root.batteryFull ? "-" : (root.batteryInfo.rate || ""))
            }
          }
        }

        PanelSeparator {
          foreground: root.foreground
        }

        Toggle {
          visible: root.chargeCapability.available
          width: parent.width
          label: "Battery protection"
          description: root.chargeCapability.description
          foreground: root.foreground
          accent: Color.accent
          fontFamily: root.fontFamily
          checked: root.chargeLimitEnabled
          enabled: !root.chargeBusy
          hasCursor: root.cursorOnCharge
          onClicked: root.setChargeLimit(!root.chargeLimitEnabled)
          onHovered: function (h) {
            if (h) {
              root.cursorRow = root.headKeys.indexOf("charge");
              root.cursorIndex = 0;
            }
          }
        }

        Toggle {
          width: parent.width
          label: "Keep running when the lid closes"
          description: root.lidBehavior.description
          foreground: root.foreground
          accent: Color.accent
          fontFamily: root.fontFamily
          checked: root.settingsView.clamshell && root.externalScreen
          enabled: root.externalScreen
          opacity: root.externalScreen ? 1 : 0.55
          hasCursor: root.cursorOnClamshell
          onClicked: root.setClamshell(!root.settingsView.clamshell)
          onHovered: function (h) {
            if (h) {
              root.cursorRow = root.headKeys.indexOf("clamshell");
              root.cursorIndex = 0;
            }
          }
        }

        Text {
          visible: !root.chargeCapability.available
          textFormat: Text.PlainText
          width: parent.width
          wrapMode: Text.Wrap
          text: "Battery protection: " + root.chargeCapability.description
          color: root.foreground
          opacity: 0.6
          font.family: root.fontFamily
          font.pixelSize: Style.font.bodySmall
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
                  hasCursor: root.cursorSource === sourceSection.index && root.cursorKind === 0 && root.cursorIndex === index
                  onClicked: root.setProfile(sourceSection.src, modelData.value)
                  onHovered: function (h) {
                    if (h) {
                      root.cursorRow = root.headRows + sourceSection.index * root.rowsPerSource;
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
                  readonly property bool lockNever: field === "sleep" && root.settingsView[Model.sourceKey(sourceSection.src, "lock")] === Model.NEVER
                  label: field === "screensaver" ? "Screensaver" : (field === "lock" ? "Lock" : "Sleep after lock")
                  // Sleep is armed only after the lock fired: with lock never it
                  // cannot happen, so the control is shown but disabled.
                  enabled: !lockNever
                  opacity: lockNever ? 0.45 : 1
                  options: Model.delayOptions(root.settingsView[key])
                  value: String(lockNever ? Model.NEVER : root.settingsView[key])
                  foreground: root.foreground
                  accent: Color.accent
                  fontFamily: root.fontFamily
                  hasCursor: root.cursorSource === sourceSection.index && root.cursorKind === 1 && root.cursorIndex === index
                  onChanged: function (v) {
                    root.setDelay(sourceSection.src, field, v);
                  }
                  onHovered: function (h) {
                    if (h) {
                      root.cursorRow = root.headRows + sourceSection.index * root.rowsPerSource + 1;
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

  component InfoPair: Row {
    property string label: ""
    property string value: ""
    width: parent.width
    spacing: Style.spacing.lg
    Text {
      id: pairLabel
      textFormat: Text.PlainText
      text: label
      color: root.foreground
      opacity: 0.6
      font.family: root.fontFamily
      font.pixelSize: Style.font.bodySmall
    }
    Item {
      width: Math.max(0, parent.width - pairLabel.implicitWidth - pairValue.implicitWidth - parent.spacing * 2)
      height: 1
    }
    Text {
      id: pairValue
      textFormat: Text.PlainText
      text: value
      color: root.foreground
      font.family: root.fontFamily
      font.pixelSize: Style.font.bodySmall
    }
  }
}
