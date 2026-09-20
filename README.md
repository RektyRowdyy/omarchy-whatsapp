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

## Permissions and dependencies

Omarchy plugins run **unsandboxed inside the long-lived `omarchy-shell`
process**, with your own user's permissions. What this one does with them:

- `bin/whatsapp-unread` runs `dbus-monitor` as a session-bus *monitor*, so the
  process sees every `org.freedesktop.Notifications.Notify` call on the bus,
  not only WhatsApp's — that's inherent to how monitoring works, there is no
  narrower subscription available. The `appNamePattern`/`matchUrl` filtering
  happens in the `awk` stage afterwards. Nothing is written to disk and nothing
  leaves the machine; the only output is one `sender<TAB>count` line per
  matching notification, on stdout, read by the widget.
- The only other command it ever spawns is `omarchy-launch-webapp
  https://web.whatsapp.com/`, via `Quickshell.execDetached`, and only on a
  click when no WhatsApp window is open.
- No installer, no remote build step, no network requests of its own, and no
  second Quickshell process.

## Installation

```bash
omarchy plugin add https://github.com/RektyRowdyy/omarchy-whatsapp.git --enable
```

This clones the plugin, validates it, and prompts for a bar section —
defaulting to `right`. To place it elsewhere, or to enable it later:

```bash
omarchy plugin enable io.github.rektyrowdyy.whatsapp --section <left|center|right>
```

Then grant notification permission for `web.whatsapp.com` in the Chromium
web-app (see Requirements above) — without it nothing ever reaches the
notification bus and the dot will never light up.

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

## Removal

```bash
omarchy plugin remove io.github.rektyrowdyy.whatsapp
```

That's the whole cleanup. The widget leaves the bar with it, and the three
settings above live in the bar's own entry in `~/.config/omarchy/shell.json`,
so they go too. The plugin writes no state of its own anywhere else — unread
counts only ever exist in memory (see Known limitations), and the
`dbus-monitor` it spawns dies with the shell process that owns it.

Removing the plugin does not touch the Chromium WhatsApp Web web-app itself.
If you want that gone as well, delete
`~/.local/share/applications/WhatsApp.desktop` and its Chromium profile
yourself.

## License

MIT — see [LICENSE](LICENSE).
