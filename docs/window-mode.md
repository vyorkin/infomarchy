# Window mode

By default this fork runs Infomarchy's dashboard as a **normal application
window** pinned to a single workspace, instead of painting it on the
`WlrLayer.Background` of every workspace.

## What the fork changes

- `Overlay.qml` is a Quickshell `FloatingWindow` (a real Wayland toplevel):
  it shows up in the window list, can be moved and resized, and is closed with
  `Esc` or the window close button.
- `Infomarchy.qml` is a headless service. It keeps collecting the snapshot and
  sending "an agent needs you" notifications while the window is closed, and
  keeps the `infomarchy` IPC target. It no longer has a Background-layer
  surface, so it can no longer draw on every workspace.
- `manifest.json` no longer declares `clonedFrom: omarchy.background`, so the
  stock `omarchy.background` service is restored and owns the `background` IPC
  target. Wallpaper changes (`omarchy theme bg set ...`) go back to it.

Everything the window shows comes from the same `InfoModel`/`InfoView` as
before, so the dashboard itself is unchanged — only its host is.

## Pinning the window to one workspace (Hyprland)

A window's workspace is a compositor concern, so it lives in the user's
Hyprland config, not in the plugin. `~/.config/hypr/infomarchy.lua`:

```lua
-- "10" is the workspace Omarchy's bar labels "0" and SUPER+0 focuses.
-- Hyprland has no numeric workspace id 0: in a window rule, "0" means
-- "leave the workspace unchanged".
o.window(
  { class = "^org\\.quickshell$", title = "^Infomarchy$" },
  { workspace = "10" }
)

-- Keep the dashboard floating; comment this out to let it tile.
o.window(
  { class = "^org\\.quickshell$", title = "^Infomarchy$" },
  { float = true }
)
```

Quickshell reports class `org.quickshell` for **all** of its windows, so the
rule also matches the title to leave other panels (dev gallery, bar panels)
untouched. Load it from `~/.config/hypr/hyprland.lua`:

```lua
require("hypr.infomarchy")
```

Change `workspace = "10"` to any other workspace id you prefer.

## Toggling with SUPER+D

Bind `SUPER + D` to a small helper that behaves like an app switcher:

```bash
# ~/.local/bin/infomarchy-dashboard
#!/usr/bin/env bash
set -euo pipefail
WORKSPACE="${INFOMARCHY_WORKSPACE:-10}"
ID="nixfred.infomarchy"

focused=$(hyprctl activewindow -j 2>/dev/null | jq -r '.title // ""')
if [ "$focused" = "Infomarchy" ]; then
  omarchy-shell shell hide "$ID" >/dev/null 2>&1 || true
  exit 0
fi

omarchy-shell shell summon "$ID" '{}' >/dev/null 2>&1 || true
hyprctl dispatch "hl.dsp.focus({ workspace = \"${WORKSPACE}\" })" >/dev/null 2>&1 || true
```

```lua
-- ~/.config/hypr/bindings.lua
o.bind("SUPER + D", "Infomarchy: dashboard window", "infomarchy-dashboard")
```

The window rule already focuses the workspace when the window opens, so a
plain `omarchy-shell shell toggle nixfred.infomarchy '{}'` also works; the
helper additionally re-shows an already-open dashboard that is on another
workspace instead of closing it.

## Why workspace "0" means workspace 10

Omarchy's bar renders workspace **10** with the label **"0"** (see the stock
`Workspaces.qml`: `modelData === 10 ? "0" : String(modelData)`), and its
default `SUPER + 0` binding focuses workspace 10. Hyprland rejects a numeric
workspace id of `0` — in a window rule, `"0"` means "leave the workspace
unchanged" — and a *named* workspace `name:0` gets a negative id that the bar
does not list. So the workspace that reads as "0" on this desktop is id `10`.
