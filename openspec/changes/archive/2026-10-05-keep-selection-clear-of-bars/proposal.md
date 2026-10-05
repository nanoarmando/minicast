## Why

Moving the selection with the keyboard can leave the selected row under the bottom action bar or inside
the faded band next to it, so the row the user is acting on is hidden or dimmed. Selection following
treats a row as visible as soon as it is inside the scroll view, without accounting for the bars or the
dissolve that reaches past them, and the lists have too little room at their ends for the first and
last rows to leave the faded bands.

## What Changes

- Keyboard selection following keeps the selected row fully opaque: clear of both floating bars and of
  the dissolve bands that extend past them, at the top and at the bottom.
- Every palette list gets room at its start and end, sized to the dissolve bands, so the first and last
  rows can reach that clear area.
- The fix lives in the shared scrolling primitives, so it applies to every palette list and grid at
  once, extension lists included. The dissolve's look is unchanged.

## Capabilities

### New Capabilities
None.

### Modified Capabilities
- `scroll-edge-effects`: "Scroll-driven effects follow the scroll position" tightens keyboard following
  from "stays visible" to "fully opaque, clear of the bars", and adds "List ends leave room for the
  bars".

## Impact

- Code: `Tinycast/DesignSystem/Scrolling/` (`SelectionFollowing.swift`, `SelectionReveal.swift`,
  `EdgeDissolve.swift`) and the content padding of every list that uses `edgeDissolve()`.
- Tests: `Tests/scroll-reveal-test.swift` gains the clearance cases.
- Docs: `docs/ui.md` (edge dissolve section) describes the clearance and the end padding.
- No data, settings or persistence changes.
