## Why

On both Macs (macOS 13 and 27), when a palette list scrolls, rows pass visibly behind the floating search
bar and the bottom action bar without fading, so text overlaps and is unreadable. The bars have no backing
by design; the edge dissolve is the only separation. In the fork, scroll-driven effects read metrics through
the `onScrollMetricsChange` compatibility helper, whose AppKit probe can give up before it finds the scroll
view, leaving the dissolve mask fully opaque. The same helper feeds the thin scrollbar, overflow fades,
selection following and the AI chat's follow-tail, which are likely broken the same way.

## What Changes

- The scroll observation helper keeps trying to find its scroll view until it succeeds (whenever the probe
  is laid out or updated), instead of giving up after a burst of same-instant retries.
- Before scroll metrics are available, the edge dissolve fades its bands with a static gradient instead of
  showing content fully opaque under the bars.
- Restores upstream behavior on every surface that uses the helper: palette lists (launcher, clipboard, file
  search, emoji, dictionary, uninstall, calculator history, schedule, meetings, rooms, chat history,
  extensions), the AI transcript, Settings and popup overflow fades, the thin scrollbar and keyboard
  selection following.

## Capabilities

### New Capabilities

- `scroll-edge-effects`: content legibility under the palette's floating bars and the scroll-driven
  effects (edge dissolve, overflow fade, thin scrollbar, selection following, transcript follow-tail).

### Modified Capabilities

None.

## Impact

- **Code**: `Tinycast/DesignSystem/Compatibility/ScrollObservation.swift`,
  `Tinycast/DesignSystem/Scrolling/EdgeDissolve.swift` (fallback only); possibly `OverflowFade.swift` for the
  same fallback.
- **Behavior**: matches upstream; no design changes and no new backgrounds on the bars.
- **Dependencies, data, project settings**: none.
