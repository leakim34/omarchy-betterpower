import QtQuick
import Quickshell.Services.UPower
import qs.Commons
import qs.Ui
import "Model.js" as Model

// Bar entry for leakz.betterpower: an icon button that opens Panel.qml. No logic
// beyond hosting the panel and handing it the bar and settings.
BarWidget {
  id: root
  moduleName: "leakz.betterpower"

  readonly property var service: bar && bar.shell && typeof bar.shell.serviceFor === "function" ? bar.shell.serviceFor("leakz.betterpower") : null
  readonly property bool batteryPresent: {
    var d = UPower.displayDevice;
    return !!(d && d.isPresent);
  }
  readonly property bool opened: panelLoader.item ? panelLoader.item.opened === true : false
  readonly property var settingsView: Model.normalizeSettings(root.settings, [])
  readonly property string barMode: settingsView.barMode
  readonly property bool showPercentage: barMode === "percentage" && !vertical
  readonly property bool showGauge: barMode === "gauge" && batteryPresent
  readonly property int percentage: {
    var d = UPower.displayDevice;
    return d && d.isPresent ? Math.round(Number(d.percentage || 0) * 100) : -1;
  }

  function cycleBarMode() {
    if (root.service)
      root.service.cycleBarMode();
  }

  function injectPanel() {
    var target = panelLoader.item;
    if (!target)
      return;
    if ("bar" in target)
      target.bar = root.bar;
    if ("settings" in target)
      target.settings = root.settings;
    if ("anchorItem" in target)
      target.anchorItem = button;
    if ("hostWidget" in target)
      target.hostWidget = root;
  }

  function togglePanel() {
    if (panelLoader.item && panelLoader.item.toggle)
      panelLoader.item.toggle();
  }

  function open() {
    if (panelLoader.item && panelLoader.item.open)
      panelLoader.item.open();
  }

  function close() {
    if (panelLoader.item && panelLoader.item.close)
      panelLoader.item.close();
  }

  function icon() {
    return Model.batteryIcon(UPower.displayDevice, UPower.onBattery, {
      Charging: UPowerDeviceState.Charging,
      Discharging: UPowerDeviceState.Discharging,
      FullyCharged: UPowerDeviceState.FullyCharged,
      PendingCharge: UPowerDeviceState.PendingCharge
    });
  }

  visible: true
  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  onBarChanged: injectPanel()
  onSettingsChanged: injectPanel()

  // Bar-wide battery gauge. The rectangle is reparented onto the bar window's
  // content item, under the sections, so it paints across the whole bar. That
  // leans on Quickshell's window tree rather than the widget contract; every
  // lookup is guarded so a shell change leaves the bar untouched.
  readonly property var gaugeHost: {
    var w = root.Window.window;
    return w && w.contentItem ? w.contentItem : null;
  }
  readonly property var gauge: Model.gaugeSpec(Model.batteryFraction(UPower.displayDevice), charging)
  readonly property bool charging: {
    var d = UPower.displayDevice;
    return !!(d && d.isPresent && (d.state === UPowerDeviceState.Charging || d.state === UPowerDeviceState.PendingCharge));
  }
  readonly property color gaugeTone: root.gauge.low ? (bar ? bar.urgent : Color.urgent) : Color.accent
  readonly property color gaugeColor: Qt.rgba(gaugeTone.r, gaugeTone.g, gaugeTone.b, root.gauge.alpha)

  Rectangle {
    id: gaugeFill
    parent: root.gaugeHost
    visible: root.showGauge && parent !== null
    z: -1
    x: 0
    y: 0
    width: parent ? (root.vertical ? parent.width : Math.round(parent.width * root.gauge.fraction)) : 0
    height: parent ? (root.vertical ? Math.round(parent.height * root.gauge.fraction) : parent.height) : 0
    color: root.gaugeColor
    Behavior on width {
      NumberAnimation {
        duration: 600
        easing.type: Easing.InOutCubic
      }
    }
    Behavior on height {
      NumberAnimation {
        duration: 600
        easing.type: Easing.InOutCubic
      }
    }
    Behavior on color {
      ColorAnimation {
        duration: 420
      }
    }

    // Soft edge at the end of the fill.
    Rectangle {
      visible: root.gauge.fraction < 1
      anchors.right: root.vertical ? undefined : parent.right
      anchors.bottom: root.vertical ? parent.bottom : undefined
      width: root.vertical ? parent.width : Math.min(24, parent.width)
      height: root.vertical ? Math.min(24, parent.height) : parent.height
      gradient: Gradient {
        orientation: root.vertical ? Gradient.Vertical : Gradient.Horizontal
        GradientStop {
          position: 0.0
          color: "transparent"
        }
        GradientStop {
          position: 1.0
          color: root.gaugeTone.r !== undefined ? Qt.rgba(root.gaugeTone.r, root.gaugeTone.g, root.gaugeTone.b, root.gauge.alpha * 0.6) : "transparent"
        }
      }
    }

    // Charging shimmer: a faint band drifting toward the fill end.
    Rectangle {
      visible: root.charging && root.showGauge
      width: root.vertical ? parent.width : 48
      height: root.vertical ? 48 : parent.height
      opacity: 0.35
      gradient: Gradient {
        orientation: root.vertical ? Gradient.Vertical : Gradient.Horizontal
        GradientStop {
          position: 0.0
          color: "transparent"
        }
        GradientStop {
          position: 0.5
          color: root.gaugeColor
        }
        GradientStop {
          position: 1.0
          color: "transparent"
        }
      }
      SequentialAnimation on x {
        running: !root.vertical && root.charging && root.showGauge
        loops: Animation.Infinite
        NumberAnimation {
          from: -48
          to: Math.max(0, gaugeFill.width)
          duration: 2400
          easing.type: Easing.InOutSine
        }
        PauseAnimation {
          duration: 800
        }
      }
      SequentialAnimation on y {
        running: root.vertical && root.charging && root.showGauge
        loops: Animation.Infinite
        NumberAnimation {
          from: -48
          to: Math.max(0, gaugeFill.height)
          duration: 2400
          easing.type: Easing.InOutSine
        }
        PauseAnimation {
          duration: 800
        }
      }
    }
  }

  Loader {
    id: panelLoader
    active: true
    source: Qt.resolvedUrl("Panel.qml")
    visible: false
    onLoaded: {
      root.injectPanel();
      Qt.callLater(root.injectPanel);
    }
  }

  BarIconButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    text: root.showPercentage && root.percentage >= 0 ? root.percentage + "% " + root.icon() : root.icon()
    slotSize: Style.bar.iconSlot * (root.showPercentage ? 2 : 1)
    tooltipText: "Power · " + Model.sourceLabel(UPower.onBattery ? "battery" : "ac")
    onPressed: function (b) {
      if (b === Qt.RightButton)
        root.cycleBarMode();
      else if (b === Qt.LeftButton)
        root.togglePanel();
    }
  }
}
