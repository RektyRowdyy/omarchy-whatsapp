import QtQuick
import qs.Commons
import qs.Ui

// Bar icon for WhatsApp Web: a Nerd Font glyph, dimmed when no WhatsApp
// window is currently open, with a plain unread-indicator dot. All polling
// and state live in Service.qml, reached through Panel.qml's re-exported
// properties — the injectPanel()/Loader wiring below follows
// crmne.hyprmoncfg's BarWidget.qml (and android-mirror's) exactly, since the
// shell's bar host only recognizes a module as summonable when open()/
// close()/opened are exposed directly on this top-level widget item.
BarWidget {
  id: root
  moduleName: "io.github.rektyrowdyy.whatsapp"

  function injectPanel() {
    var target = panelLoader.item
    if (!target) return
    if ("bar" in target) target.bar = root.bar
    if ("settings" in target) target.settings = root.settings
    if ("anchorItem" in target) target.anchorItem = button
    if ("hostWidget" in target) target.hostWidget = root
  }

  function open() {
    if (panelLoader.item && panelLoader.item.open) panelLoader.item.open()
  }

  function close() {
    if (panelLoader.item && panelLoader.item.close) panelLoader.item.close()
  }

  function togglePanel() {
    if (panelLoader.item && panelLoader.item.toggle) panelLoader.item.toggle()
  }

  readonly property bool opened: panelLoader.item ? panelLoader.item.opened === true : false
  readonly property var senders: panelLoader.item ? panelLoader.item.senders : ({})
  readonly property int total: panelLoader.item ? panelLoader.item.total : 0
  readonly property bool windowOpen: panelLoader.item ? panelLoader.item.windowOpen === true : false
  readonly property string tooltipText: panelLoader.item ? panelLoader.item.tooltipText : "WhatsApp"

  readonly property color activeIconColor: bar ? bar.barForeground : Color.foreground
  readonly property color dimIconColor: Qt.darker(activeIconColor, 1.6)

  // Left-click jumps straight to WhatsApp and clears the badge — the badge
  // means "unread since you last looked", so looking is what should clear
  // it, same as this Service does automatically on window focus. If
  // WhatsApp isn't open, focusOrLaunch() opens it instead, and the badge is
  // left alone since nothing was actually read yet.
  // Right-click opens the sender list without leaving the bar.
  function focusWhatsApp() {
    if (!panelLoader.item || !panelLoader.item.focusOrLaunch) return
    if (panelLoader.item.focusOrLaunch() && panelLoader.item.clear) panelLoader.item.clear()
  }

  // Peer-relay entry points for Service's launch guard: the base BarWidget's
  // broadcast() calls these on every monitor's instance of this widget, and
  // each hands the call down to its own Service (see Panel.qml's
  // relayToPeers). Nothing else should call them directly.
  function armLaunchGuard() {
    if (panelLoader.item && panelLoader.item.armLaunchGuard) panelLoader.item.armLaunchGuard()
  }

  function clearLaunchGuard() {
    if (panelLoader.item && panelLoader.item.clearLaunchGuard) panelLoader.item.clearLaunchGuard()
  }

  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  onBarChanged: injectPanel()
  onSettingsChanged: injectPanel()

  Loader {
    id: panelLoader
    active: true
    visible: false
    source: Qt.resolvedUrl("Panel.qml")
    onLoaded: {
      root.injectPanel()
      Qt.callLater(root.injectPanel)
    }
  }

  BarIconButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    text: ""
    slotSize: Style.bar.iconSlot
    opticalSize: Style.bar.iconCanvas
    fontSize: Style.bar.iconFont
    active: root.opened
    tooltipText: root.tooltipText

    iconComponent: Component {
      Item {
        OpticalGlyph {
          id: waGlyph
          anchors.fill: parent
          text: button.text
          color: button.active ? button.activeColor : (root.windowOpen ? button.foreground : root.dimIconColor)
          fontFamily: button.fontFamily
          fontSize: button.fontSize
        }

        // Plain unread indicator, not a count: WhatsApp's own badge is the
        // authority on how many, and this can only ever show "notifications
        // arrived since you last looked" — showing a specific number next to
        // that asterisk read as more precise than it is. Right-click (or the
        // panel it opens) is where the actual per-sender counts belong.
        BorderSurface {
          visible: root.total > 0
          width: Math.max(7, Style.bar.iconCanvas * 0.38)
          height: width
          radius: width / 2
          color: Color.urgent
          anchors.right: waGlyph.right
          anchors.bottom: waGlyph.bottom
          anchors.rightMargin: -Style.space(2)
          anchors.bottomMargin: -Style.space(1)
          borderSpec: Border.flat(Color.popups.background, 1)
        }
      }
    }

    onPressed: function(b) {
      if (b === Qt.RightButton) root.togglePanel()
      else root.focusWhatsApp()
    }
  }
}
