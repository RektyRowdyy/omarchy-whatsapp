# WhatsApp

Omarchy bar widget for WhatsApp Web: a bar icon with a plain unread dot,
dimmed when WhatsApp isn't running. Click to open or focus it, right-click
for a list of who's waiting.

## Why this exists

WhatsApp Web is a linked device holding its own websocket to WhatsApp's
servers — there is no server-side inbox this could poll, and the window's
title never updates past the bare `web.whatsapp.com` hostname, even when
focused. The one signal that *is* reliable is the desktop notification
Chromium raises for every incoming message, so this watches for those
instead: `bin/whatsapp-unread` eavesdrops on the session bus'
`org.freedesktop.Notifications` `Notify` calls with `dbus-monitor` (any
client can *monitor* calls addressed to someone else, even though only one
process may *own* the Notifications name) and emits one `sender<TAB>count`
line per WhatsApp message.

**This means WhatsApp Web has to be running** — killing the browser tab
kills the websocket that would ever notify you of anything. Nothing launches
at shell start: left-click the icon and it opens WhatsApp if it isn't
running; it doesn't force a workspace, so it opens wherever your Hyprland
window rules put it.

The dot lights up on any notification received since you last focused
WhatsApp and clears the same way — reading on your phone doesn't clear it,
opening the window does (either by clicking the icon or switching to it
another way). It's deliberately not a count: this can only ever reflect
notifications *seen*, not WhatsApp's own unread total, so a specific number
next to it would read as more precise than it actually is. Right-click the
icon for the real per-sender breakdown.

Left-click focuses the existing WhatsApp window if there is one (matched by
window class, never title), otherwise launches it with
`omarchy-launch-webapp https://web.whatsapp.com/`. If WhatsApp isn't running
the icon renders dimmed. Repeat clicks within a few seconds of a launch don't
spawn a second window.

## Requirements

- Chromium's WhatsApp Web web-app (`~/.local/share/applications/WhatsApp.desktop`,
  installed by Omarchy's `omarchy-launch-webapp`) with notification
  permission granted for `web.whatsapp.com`.
- `dbus-monitor` (part of `dbus`, present on any Omarchy install).

## Installation

```bash
git clone https://github.com/RektyRowdyy/whatsapp.git
cd whatsapp
./scripts/dev-install.sh
omarchy plugin enable io.github.rektyrowdyy.whatsapp --section right
```

## Development

After editing `Service.qml`, `Panel.qml`, or `Model.js`, `./scripts/dev-install.sh`
alone is not enough to see the change: it copies files and calls
`omarchy-shell shell rescanPlugins`, but that does not reliably re-instantiate
a component already loaded through a `Loader` (Panel.qml is loaded that way
from BarWidget.qml) — the shell can keep running the old, already-compiled
version indefinitely with no error. Confirmed directly: instrumented logging
added to `Service.qml` produced zero output through several rescans, then
appeared immediately after `omarchy-restart-shell`. Run that after any change
to these three files before trusting what you see.

## Settings

| Key | Default | Meaning |
|---|---|---|
| `appNamePattern` | `Chromium\|Google Chrome\|Brave\|Chrome` | Notification sender app-name filter |
| `matchUrl` | `web.whatsapp.com` | Notification body substring/regex filter |
| `windowClassPattern` | `whatsapp` | Window class/app-id pattern used to detect and focus the WhatsApp window |

## Known limitations

- WhatsApp Web must stay running for the indicator to work at all — see above.
- Reflects notifications since last open, not WhatsApp's true unread state —
  reading on your phone doesn't clear it.
- Unread state resets on shell restart (nothing persists it to disk).
