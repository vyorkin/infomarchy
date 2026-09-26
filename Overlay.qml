import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui

// Windowed host. Infomarchy's dashboard lives in a real Wayland application
// window (Quickshell FloatingWindow) instead of a fullscreen layer-shell
// surface, so it behaves like any other app: it appears in the window list,
// can be moved/resized, and — pinned to one workspace by a Hyprland window
// rule (see ~/.config/hypr/infomarchy.lua) — shows on that workspace alone.
//
// SUPER+D toggles it, exactly as before. Esc or the window close button also
// closes it, and both keep the shell's open/closed bookkeeping in sync.
Scope {
  id: root

  // Injected by the shell's panel loader so close() can tell the host.
  property var shell: null
  property bool opened: false
  // Set while the host itself is closing us, so the window's onVisibleChanged
  // does not bounce a redundant hide() back to the shell.
  property bool closingFromHost: false

  InfoModel { id: infoModel; refreshMs: 3000; active: root.opened; instance: "overlay"; demoMode: demoMarker.present; ollamaHost: dashboardSettings.ollamaHost }
  InfoSettings { id: dashboardSettings }
  // Demo mode is set on the service; a screenshot taken with the window open
  // must not leak live prompts. Mirror the runtime marker.
  FileView {
    id: demoMarker
    property bool present: false
    path: (Quickshell.env("XDG_RUNTIME_DIR") || ("/run/user/" + Quickshell.env("UID"))) + "/infomarchy-demo"
    watchChanges: true
    printErrors: false
    onLoaded: present = true
    onLoadFailed: present = false
    onFileChanged: reload()
  }

  function open(payload) {
    root.closingFromHost = false
    root.opened = true
    demoMarker.reload()
    infoModel.refresh()
    Qt.callLater(function() { if (keyCatcher) keyCatcher.forceActiveFocus() })
  }
  // Host-initiated close (`shell hide`). Visibility flips without notifying
  // the host back — it already knows.
  function close() {
    root.closingFromHost = true
    root.opened = false
    root.closingFromHost = false
  }
  function toggle(payload) { if (root.opened) close(); else open(payload) }
  // `omarchy-shell shell call nixfred.infomarchy refresh` also lands here.
  function refresh() { infoModel.refresh() }

  // User-initiated close (Esc, window close button). Tell the shell so its
  // openPanelIds map stays consistent and toggle() works on the next call.
  function requestClose() {
    if (root.shell && typeof root.shell.hide === "function") root.shell.hide("nixfred.infomarchy")
    else root.opened = false
  }

  FloatingWindow {
    id: window
    title: "Infomarchy"
    color: infoModel.themeBackground
    visible: root.opened
    // The dashboard was designed for a full desk; default the window large so
    // every column is visible, while staying resizable and never below a
    // usable minimum on a small screen.
    implicitWidth: 3240
    implicitHeight: 1320
    minimumSize: Qt.size(960, 600)
    onVisibleChanged: if (!visible && !root.closingFromHost) root.requestClose()

    Rectangle {
      id: keyCatcher
      anchors.fill: parent
      color: infoModel.themeBackground
      focus: root.opened
      // Esc closes ABOUT first, then the window — one panel deep, so a reader
      // who opened it does not lose the whole dashboard on the way out.
      Keys.onEscapePressed: { if (infoView.aboutOpen) infoView.aboutOpen = false; else root.requestClose() }
      Keys.onPressed: function(event) {
        // SUPER+I inside the window keeps its privacy meaning; the plain
        // SUPER+I (hide/show the desk) is now just the window toggle.
        if ((event.modifiers & Qt.MetaModifier) && event.key === Qt.Key_I) {
          if (event.modifiers & Qt.ShiftModifier) {
            if (!event.isAutoRepeat) dashboardSettings.togglePrivacyMode()
          } else {
            root.requestClose()
          }
          event.accepted = true
          return
        }
        if (event.key >= Qt.Key_0 && event.key <= Qt.Key_9) { var i = event.key === Qt.Key_0 ? 9 : event.key - Qt.Key_1; var def = dashboardSettings.definitions[i]; if (def) dashboardSettings.toggleSection(def.id); event.accepted = true; return }
        if (event.key === Qt.Key_J || event.key === Qt.Key_Down) { infoView.keyboardStep(1); event.accepted = true; return }
        if (event.key === Qt.Key_K || event.key === Qt.Key_Up) { infoView.keyboardStep(-1); event.accepted = true; return }
        if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) { infoView.activateKeyboardSession(); event.accepted = true; return }
        if (event.key === Qt.Key_A) { infoView.clearActivityFilter(); event.accepted = true }
      }

      InfoView {
        id: infoView
        anchors.fill: parent
        desk: infoModel
        settings: dashboardSettings
        interactive: true
        keyboardAvailable: true
        topInset: Style.spacing.xl
        rightInset: Style.spacing.lg
        bottomInset: Style.spacing.xl
        leftInset: Style.spacing.lg
        onNavigated: root.requestClose()
      }
    }
  }
}
