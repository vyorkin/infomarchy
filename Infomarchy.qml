import QtQuick
import Quickshell
import Quickshell.Io

// Headless service. This file used to be the wallpaper host: it replaced
// omarchy.background and painted the dashboard on the Background layer of
// every workspace. It is now the data/notification service only — it keeps
// collecting the machine and agent snapshot and sends "an agent needs you"
// notifications while the windowed dashboard (Overlay.qml) is closed.
//
// The wallpaper role is handed back to stock omarchy.background (manifest.json
// no longer declares clonedFrom), and there is no Background-layer surface
// here any more, so the dashboard can only appear as the app window.
Scope {
  id: root

  // Declared so the shell's injection contract is unchanged even though there
  // is no bar-aware surface here any more.
  property var shell: null

  // Transient sanitized sample data for public screenshots. Never persisted
  // across a login: the flag lives as a marker file under XDG_RUNTIME_DIR so
  // the window (a separate Scope with its own InfoModel) sees the same mode,
  // and the file is removed on every shell start.
  property bool demoMode: false
  readonly property string demoMarkerPath: (Quickshell.env("XDG_RUNTIME_DIR") || ("/run/user/" + Quickshell.env("UID"))) + "/infomarchy-demo"
  Process { id: demoMarkerWriter; property var pending: []; command: pending }
  function publishDemoMarker(on) {
    demoMarkerWriter.pending = on ? ["touch", root.demoMarkerPath] : ["rm", "-f", root.demoMarkerPath]
    demoMarkerWriter.running = true
  }
  Component.onCompleted: publishDemoMarker(false)

  // Collecting costs ~20 subprocesses a tick (/proc scan, df, ping, iw,
  // hyprctl, nvidia-smi, git per session, a full opencode.db scan). This
  // service exists so notifications keep working while the window is closed,
  // so it idles at a quarter cadence unless the dashboard says otherwise.
  InfoModel {
    id: infoModel
    refreshMs: dashboardSettings.dashboardVisible ? 4000 : 16000
    demoMode: root.demoMode
    ollamaHost: dashboardSettings.ollamaHost
    active: dashboardSettings.ready && (dashboardSettings.dashboardVisible || dashboardSettings.notificationsEnabled)
  }
  InfoSettings { id: dashboardSettings }

  function dispatchNotifications() {
    if (root.demoMode || !dashboardSettings.ready || !infoModel.ready) return
    var events = (((infoModel.snap || {}).ai || {}).events || []).slice(0, 64)
    var stamp = Number((infoModel.snap || {}).ts || Date.now())
    for (var i = 0; i < events.length; i++) {
      var event = events[i] || {}, key = String(event.key || "")
      // Decide eligibility BEFORE claiming the key: a signal that arrives
      // during quiet hours or while its provider is muted used to be marked
      // delivered and never shown once alerts were allowed again.
      if (event.attentionKey && !dashboardSettings.attentionVisible(String(event.attentionKey), stamp)) continue
      if (!dashboardSettings.notificationsAllowed(String(event.provider || ""), stamp)) continue
      if (!dashboardSettings.claimNotificationEvent(key, stamp)) continue
      var title = infoModel.plainText(event.title || "Infomarchy", 100)
      var body = infoModel.plainText(event.body || "AI session changed", 240)
      var urgency = event.urgency === "normal" ? "normal" : "low"
      // The notification body opens the windowed dashboard on the workspace it
      // is pinned to (see ~/.config/hypr/infomarchy.lua).
      Quickshell.execDetached([
        "omarchy-notification-send", "--app-name", "Infomarchy", "-u", urgency, "-t", "8000",
        title, body, "--exec", "omarchy-shell", "shell", "toggle", "nixfred.infomarchy", "{}"
      ])
    }
  }

  Connections {
    target: infoModel
    function onSnapChanged() { root.dispatchNotifications() }
    function onReadyChanged() { if (infoModel.ready) root.dispatchNotifications() }
  }
  Connections {
    target: dashboardSettings
    function onReadyChanged() { if (dashboardSettings.ready) root.dispatchNotifications() }
  }

  // Settings and control surface for the windowed dashboard. The window has
  // its own InfoModel/InfoSettings instance but shares the same persisted
  // dashboard.json, so every setter here is seen by the window too.
  IpcHandler {
    target: "infomarchy"
    function refresh(): void { infoModel.refresh() }
    function setDashboardVisible(v: string): void { dashboardSettings.setDashboardVisible(["1", "true", "on", "yes"].indexOf(String(v).toLowerCase()) >= 0) }
    function toggleDashboard(): void { dashboardSettings.toggleDashboardVisible() }
    function getDashboardVisible(): string { return dashboardSettings.dashboardVisible ? "true" : "false" }
    function setOllamaHost(v: string): void { dashboardSettings.setOllamaHost(v) }
    function getOllamaHost(): string { return String(dashboardSettings.ollamaHost || "") }
    function setPrivacy(v: string): void { dashboardSettings.setPrivacyMode(["1", "true", "on", "yes"].indexOf(String(v).toLowerCase()) >= 0) }
    function togglePrivacy(): void { dashboardSettings.togglePrivacyMode() }
    function getPrivacy(): string { return dashboardSettings.privacyMode ? "true" : "false" }
    // The dashboard is a window now; geometry is intrinsic to it, so this
    // reports nothing rather than a stale surface that no longer exists.
    function geometry(): string { return "{}" }
    function setSection(id: string, v: string): void { dashboardSettings.setSection(id, ["1", "true", "on", "yes"].indexOf(String(v).toLowerCase()) >= 0) }
    function toggleSection(id: string): void { dashboardSettings.toggleSection(id) }
    function setNotifications(v: string): void { dashboardSettings.setNotificationsEnabled(["1", "true", "on", "yes"].indexOf(String(v).toLowerCase()) >= 0) }
    function toggleNotifications(): void { dashboardSettings.toggleNotificationsEnabled() }
    function setQuietHours(v: string): void { dashboardSettings.setQuietHoursEnabled(["1", "true", "on", "yes"].indexOf(String(v).toLowerCase()) >= 0) }
    function toggleQuietHours(): void { dashboardSettings.toggleQuietHoursEnabled() }
    // Idle sessions drop off the dashboard by default; this puts them back
    // without a rebuild, and setQuietMinutes moves the line they fall behind.
    function setHideQuiet(v: string): void { dashboardSettings.setHideQuietSessions(["1", "true", "on", "yes"].indexOf(String(v).toLowerCase()) >= 0) }
    function toggleHideQuiet(): void { dashboardSettings.toggleHideQuietSessions() }
    function getHideQuiet(): string { return dashboardSettings.hideQuietSessions ? "true" : "false" }
    function setQuietMinutes(v: string): void { dashboardSettings.setSessionQuietMinutes(Number(v)) }
    function getQuietMinutes(): string { return String(dashboardSettings.sessionQuietMinutes) }
    function setDemo(v: string): void {
      root.demoMode = ["1", "true", "on", "yes"].indexOf(String(v).toLowerCase()) >= 0
      root.publishDemoMarker(root.demoMode)
      infoModel.refresh()
    }
    function getDemo(): string { return root.demoMode ? "true" : "false" }
  }
}
