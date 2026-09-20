import QtQuick
import qs.Commons
import qs.Ui
import "Model.js" as Model

// Popup content for the WhatsApp bar widget: a hero row plus a list of
// senders with unread counts. Loaded by BarWidget.qml's Loader, which also
// injects `bar`, `settings`, and `anchorItem` (see injectPanel() there).
//
// All watcher-process handling and unread state live in Service.qml (svc
// below) — this file only holds layout and keyboard-navigation state,
// matching the Panel+Service split android-mirror and the shell's own
// plugins/panels/tailscale use. `senders`, `total`, `tooltipText`,
// `windowOpen`, `focusOrLaunch`, and `clear` are re-exposed on root because
// BarWidget.qml reaches into `panelLoader.item.*` directly (it has no
// reference to `svc`).
Panel {
  id: root
  moduleName: "io.github.rektyrowdyy.whatsapp"
  ipcTarget: "io.github.rektyrowdyy.whatsapp"
  // manageIpc left at its default (true): the base Panel's own open/close/
  // toggle IPC handler is all this popup needs.

  property var anchorItem: null
  property var hostWidget: null
  readonly property var barIdentity: hostWidget || root

  readonly property color foreground: bar ? bar.foreground : Color.foreground
  readonly property color dim: Qt.darker(foreground, 1.5)
  readonly property string fontFamily: bar ? bar.fontFamily : Style.font.family

  readonly property var senders: svc.senders
  readonly property int total: svc.total
  readonly property string tooltipText: svc.tooltipText
  readonly property bool windowOpen: svc.windowOpen
  readonly property var senderList: Model.sortedSenders(svc.senders)

  function focusOrLaunch() { return svc.focusOrLaunch() }
  function clear() { svc.clear() }

  // The launch guard lives in Service, and the bar builds one Panel — so one
  // Service — per monitor, so a guard armed here says nothing about a click
  // on the next monitor's icon: unrelayed, two such clicks inside the guard
  // window launch two WhatsApp windows. The base BarWidget's broadcast() runs
  // a method on every live instance of this module, which is exactly the
  // reach needed; these two are its entry points on this side.
  function armLaunchGuard() { svc.armLaunchGuard() }
  function clearLaunchGuard() { svc.clearLaunchGuard() }

  function relayToPeers(method) {
    if (hostWidget && typeof hostWidget.broadcast === "function") hostWidget.broadcast(method)
  }

  property int cursorIndex: 0
  property bool cursorActive: false

  function openFromHotkey() {
    open()
  }

  // The base Panel's switchPanel (Ui/Panel.qml) passes `root` — the Panel
  // itself — as the owner to look up in the bar's slot table, but Bar.qml
  // matches slots against the *BarWidget*. Since this popup is loaded via a
  // Loader from BarWidget.qml rather than being the bar widget itself, that
  // lookup always misses and Tab-to-next-panel silently does nothing.
  // Override with the same barIdentity fix android-mirror's Panel.qml uses.
  function switchPanel(direction) {
    if (root.bar && typeof root.bar.switchPanelFrom === "function")
      return root.bar.switchPanelFrom(root.barIdentity, direction)
    return false
  }

  // --- keyboard navigation ----------------------------------------------

  function rowCount() {
    return senderList.length
  }

  function moveCursor(dy) {
    var count = rowCount()
    if (count === 0) return
    root.cursorActive = true
    root.cursorIndex = ((root.cursorIndex + dy) % count + count) % count
  }

  function activateCursor() {
    focusAndClose()
  }

  // Only clears unread state on a real focus — if WhatsApp wasn't open,
  // focusOrLaunch() started it instead, and nothing was actually read.
  function focusAndClose() {
    if (svc.focusOrLaunch()) svc.clear()
    root.close()
  }

  Service {
    id: svc
    settings: root.settings
  }

  Connections {
    target: svc
    function onLaunchStarted() { root.relayToPeers("armLaunchGuard") }
    function onLaunchFailed() { root.relayToPeers("clearLaunchGuard") }
    function onSendersChanged() {
      if (root.cursorIndex >= root.senderList.length) root.cursorIndex = Math.max(0, root.senderList.length - 1)
    }
  }

  KeyboardPanel {
    id: panel
    anchorItem: root.anchorItem
    owner: root.barIdentity
    bar: root.bar
    open: root.opened
    focusTarget: keyCatcher
    contentWidth: panel.fittedContentWidth(Style.space(300))
    contentHeight: panel.fittedContentHeight(column.implicitHeight)

    PanelKeyCatcher {
      id: keyCatcher
      anchors.fill: parent
      onMoveRequested: function(dx, dy) { if (dy !== 0) root.moveCursor(dy) }
      onActivateRequested: root.activateCursor()
      onCloseRequested: root.close()
      onTabRequested: function(direction) { root.switchPanel(direction) }

      Column {
        id: column
        width: parent.width
        spacing: Style.space(14)

        // --- hero row ------------------------------------------------

        Item {
          width: parent.width
          implicitHeight: Math.max(heroGlyph.implicitHeight, heroLabels.implicitHeight)

          Text {
            id: heroGlyph
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            text: ""
            color: root.foreground
            font.family: root.fontFamily
            font.pixelSize: Style.font.display
            opacity: !root.windowOpen ? 0.4 : (root.total > 0 ? 1.0 : 0.6)
          }

          Column {
            id: heroLabels
            anchors.left: heroGlyph.right
            anchors.leftMargin: Style.space(14)
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            spacing: Style.space(1)

            Text {
              width: parent.width
              text: "WhatsApp"
              color: root.foreground
              font.family: root.fontFamily
              font.pixelSize: Style.font.title
              font.bold: true
              elide: Text.ElideRight
            }

            Text {
              width: parent.width
              // Same precedence as Model.tooltipFor: unread counts stand on
              // their own, since closing the window without focusing it
              // leaves them uncleared and the list below still shows them.
              text: root.total > 0
                ? (root.total + " unread" + (root.windowOpen ? "" : ", not running"))
                : (root.windowOpen ? "No unread messages" : "Not running")
              color: root.dim
              font.family: root.fontFamily
              font.pixelSize: Style.font.caption
              font.bold: true
              elide: Text.ElideRight
            }
          }
        }

        PanelSeparator { foreground: root.foreground }

        // --- senders -----------------------------------------------------

        PanelSectionHeader {
          text: "UNREAD"
          foreground: root.foreground
          fontFamily: root.fontFamily
        }

        Column {
          width: parent.width
          spacing: Style.space(4)
          visible: root.senderList.length > 0

          Repeater {
            model: root.senderList

            SenderRow {
              width: column.width
              rowIndex: index
              senderName: modelData.name
              senderCount: modelData.count
            }
          }
        }

        Text {
          visible: root.senderList.length === 0
          width: parent.width
          text: "You're all caught up"
          color: root.dim
          font.family: root.fontFamily
          font.pixelSize: Style.font.body
          wrapMode: Text.WordWrap
        }

        PanelSeparator { foreground: root.foreground }

        ActionRow {
          width: parent.width
          icon: "󰏌"
          title: "Open WhatsApp"
          subtitle: root.windowOpen ? "Focus the window and clear unread" : "Launch WhatsApp Web"
          onActivated: root.focusAndClose()
        }
      }
    }
  }

  component ActionRow: CursorSurface {
    id: actionRow
    property string icon: ""
    property string title: ""
    property string subtitle: ""
    signal activated()

    foreground: root.foreground
    implicitHeight: actionContent.implicitHeight + Style.spacing.rowPaddingX

    MouseArea {
      anchors.fill: parent
      hoverEnabled: true
      cursorShape: Qt.PointingHandCursor
      onEntered: parent.hasCursor = true
      onExited: parent.hasCursor = false
      onClicked: actionRow.activated()
    }

    Row {
      id: actionContent
      anchors.left: parent.left
      anchors.right: parent.right
      anchors.verticalCenter: parent.verticalCenter
      anchors.leftMargin: Style.space(12)
      anchors.rightMargin: Style.space(12)
      spacing: Style.space(12)

      Text {
        anchors.verticalCenter: parent.verticalCenter
        text: actionRow.icon
        color: root.foreground
        font.family: root.fontFamily
        font.pixelSize: Style.font.icon
      }

      Column {
        width: parent.width - parent.children[0].width - parent.spacing
        anchors.verticalCenter: parent.verticalCenter
        spacing: Style.space(2)

        Text {
          width: parent.width
          text: actionRow.title
          color: root.foreground
          font.family: root.fontFamily
          font.pixelSize: Style.font.body
          font.bold: true
          elide: Text.ElideRight
        }

        Text {
          visible: actionRow.subtitle !== ""
          width: parent.width
          text: actionRow.subtitle
          color: root.dim
          font.family: root.fontFamily
          font.pixelSize: Style.font.bodySmall
          wrapMode: Text.WordWrap
        }
      }
    }
  }

  component SenderRow: CursorSurface {
    id: row
    // Deliberately plain, not `required`: marking these `required` on an
    // inline `component X: Base { ... }` type instantiated by a Repeater's
    // explicit delegate bindings silently breaks construction — confirmed
    // by android-mirror's Panel.qml against the same base (CursorSurface).
    property int rowIndex: 0
    property string senderName: ""
    property int senderCount: 0

    readonly property bool rowSelected: root.cursorActive && root.cursorIndex === rowIndex

    hasCursor: rowSelected
    foreground: root.foreground
    implicitHeight: rowContent.implicitHeight + Style.spacing.rowPaddingX

    MouseArea {
      anchors.fill: parent
      hoverEnabled: true
      cursorShape: Qt.PointingHandCursor
      onContainsMouseChanged: if (containsMouse) {
        root.cursorActive = true
        root.cursorIndex = row.rowIndex
      }
      onClicked: root.focusAndClose()
    }

    Item {
      id: rowContent
      anchors.left: parent.left
      anchors.right: parent.right
      anchors.verticalCenter: parent.verticalCenter
      anchors.leftMargin: Style.space(10)
      anchors.rightMargin: Style.space(10)
      implicitHeight: Math.max(nameText.implicitHeight, countText.implicitHeight)

      Text {
        id: nameText
        anchors.left: parent.left
        anchors.right: countText.left
        anchors.rightMargin: Style.space(8)
        anchors.verticalCenter: parent.verticalCenter
        text: row.senderName
        textFormat: Text.PlainText
        color: root.foreground
        font.family: root.fontFamily
        font.pixelSize: Style.font.body
        elide: Text.ElideRight
      }

      Text {
        id: countText
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        text: String(row.senderCount)
        color: Color.urgent
        font.family: root.fontFamily
        font.pixelSize: Style.font.bodySmall
        font.bold: true
      }
    }
  }
}
