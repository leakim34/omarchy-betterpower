import QtQuick
import Quickshell.Services.UPower
import qs.Commons
import qs.Ui
import "Model.js" as Model

// Bar entry for leakz.power: an icon button that opens Panel.qml. No logic
// beyond hosting the panel and handing it the bar and settings.
BarWidget {
  id: root
  moduleName: "leakz.power"

  readonly property var service: bar && bar.shell && typeof bar.shell.serviceFor === "function" ? bar.shell.serviceFor("leakz.power") : null
  readonly property bool batteryPresent: {
    var d = UPower.displayDevice;
    return !!(d && d.isPresent);
  }
  readonly property bool opened: panelLoader.item ? panelLoader.item.opened === true : false

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
    text: root.icon()
    tooltipText: "Power · " + Model.sourceLabel(UPower.onBattery ? "battery" : "ac")
    onPressed: function (b) {
      if (b === Qt.LeftButton)
        root.togglePanel();
    }
  }
}
