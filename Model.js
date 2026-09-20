// Pure helpers for the WhatsApp bar widget. Kept out of QML so the parsing
// and formatting logic can be reasoned about (and unit-tested) without a
// running Quickshell process — same rationale as android-mirror's Model.js.

// Parses one line emitted by bin/whatsapp-unread: "<sender>\t<count>".
// Never throws: a malformed line (missing tab, empty sender) is dropped
// rather than corrupting the sender map with a bogus entry.
function parseWatcherLine(line) {
  var text = String(line || "")
  var tab = text.indexOf("\t")
  if (tab < 0) return null

  var sender = text.slice(0, tab)
  if (sender.length === 0) return null

  var count = parseInt(text.slice(tab + 1), 10)
  if (!isFinite(count) || count < 1) count = 1

  return { sender: sender, count: count }
}

// Senders is a map of name -> latest count (see Service.qml header comment
// for why "latest", not "summed"). Total unread is just the sum of that map.
function totalUnread(senders) {
  var total = 0
  for (var name in senders) {
    if (Object.prototype.hasOwnProperty.call(senders, name)) total += senders[name]
  }
  return total
}

// Senders sorted by unread count (desc), name as tiebreaker — the order the
// panel lists them in, busiest chat first.
function sortedSenders(senders) {
  var entries = []
  for (var name in senders) {
    if (Object.prototype.hasOwnProperty.call(senders, name)) entries.push({ name: name, count: senders[name] })
  }
  entries.sort(function(a, b) {
    if (b.count !== a.count) return b.count - a.count
    return a.name < b.name ? -1 : (a.name > b.name ? 1 : 0)
  })
  return entries
}

// Bar-icon tooltip: one line per sender, or an explicit empty/not-running
// state so hovering never just shows a blank tooltip.
function tooltipFor(senders, total, windowOpen) {
  if (!windowOpen) return "WhatsApp\nNot running — click to open"
  if (total <= 0) return "WhatsApp\nNo unread messages"
  var lines = sortedSenders(senders).map(function(e) { return e.name + " (" + e.count + ")" })
  return "WhatsApp — " + total + " unread\n" + lines.join("\n")
}

// True when a Wayland toplevel's appId identifies the WhatsApp Web window
// (chrome-web.whatsapp.com__-Default). `pattern` is user-configurable
// (manifest key windowClassPattern) so a differently-named web-app profile
// still matches. Falls back to a plain substring check if the pattern isn't
// valid regex, so a typo'd override degrades to "still finds WhatsApp"
// rather than "never matches anything again".
function isWhatsAppAppId(appId, pattern) {
  var id = String(appId || "")
  if (id.length === 0) return false
  try {
    return new RegExp(String(pattern || "whatsapp"), "i").test(id)
  } catch (e) {
    return id.toLowerCase().indexOf("whatsapp") >= 0
  }
}

// Shallow copy of a plain {name: count} map. Service.qml's `senders` is a
// plain JS object property — QML only notifies bindings on *reassignment*,
// not on mutating an existing object in place — so every update clones,
// edits the clone, and reassigns it, the same pattern android-mirror's
// Service.qml uses for configState.
function cloneJsonLike(obj) {
  var copy = {}
  for (var key in obj) {
    if (Object.prototype.hasOwnProperty.call(obj, key)) copy[key] = obj[key]
  }
  return copy
}

// Strips a file:// prefix (e.g. from Qt.resolvedUrl(...).toString()) down to
// a plain filesystem path. Duplicated from android-mirror's Model.js rather
// than shared: BarWidget.qml and Service.qml each resolve bin/whatsapp-unread's
// absolute path independently, with no common ancestor to hoist one onto.
function stripFileUrl(url) {
  return String(url).replace(/^file:\/\//, "")
}
