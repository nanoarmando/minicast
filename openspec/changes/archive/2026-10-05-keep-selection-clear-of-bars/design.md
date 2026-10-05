## Context

Every palette list pairs `.edgeDissolve()` with `.scrollFollowsSelection(_:)`
(`DesignSystem/Scrolling/SelectionFollowing.swift`). The header and the bottom bar are attached with
`.safeAreaInset` in `RootPaletteView`, so the list underlaps them. `EdgeDissolveMask` fades a top band of
`headerHeight + headerPadding + 32` and a bottom band of `bottomBarHeight + 28` (scaled), measured from the
scroll view's full frame.

`SelectionFollowing.align()` asks `SelectionReveal.edge(rowTop:rowBottom:band:)` whether the row is
inside `[0, containerSize.height]`, measured from the scroll view's global frame. That band ignores the
safe-area insets and the dissolve overshoot. When it says "outside", the list scrolls with
`scrollTo(row, anchor: .top/.bottom)`, which lands the row flush with an edge, still inside the faded
band. Lists pad their content with only `xs` at the top and `md` at the bottom, so the first and last
rows cannot reach a clear area.

## Goals / Non-Goals

**Goals:**
- A keyboard-selected row always ends fully opaque, clear of both bars and their faded bands.
- One fix in the shared scrolling primitives covers every list, grid and extension surface.
- The clearance and the end padding come from the same values as the dissolve, so they cannot drift.

**Non-Goals:**
- Changing the dissolve's band lengths, alpha floors or look (`EdgeDissolve` stays tuned by eye).
- Mouse and trackpad scrolling behavior, `.center` landings, and the `.top` origin snap.
- Surfaces that do not sit under the palette bars: `ExtensionPickerList`, `ExtensionActionsPanel`,
  `PopoverMenu`, Settings reveal and the AI transcript.

## Decisions

### D1: One source for the dissolve bands
`EdgeDissolve.swift` exposes the band lengths (bar plus overshoot, top and bottom) as a small value
derived from `InterfaceMetrics`, used by the mask, by selection following and by the end padding. The
private `topFade`/`bottomFade` become reads of that value. Alternative considered: duplicating 32/28 in
`SelectionFollowing`, rejected because the two would drift at other interface sizes.

### D2: The clear band is the frame minus both dissolve bands
`SelectionReveal.edge` takes the clear band as `top` and `bottom` limits measured from the scroll view's
full frame: `top = topFade`, `bottom = containerHeight − bottomFade`. The 0.5pt tolerance and the
"taller than the band shows its top" rule stay. Before coding, a debug print confirms whether
`containerSize` and the global `viewport` frame include the bar underlap, on macOS 13 and macOS 27; the
limits are then expressed in that same coordinate space. This also fixes the case where a row under the
bottom bar counts as inside today.

### D3: Land the row inside the clear band with a unit-point anchor
`scrollTo(row, anchor:)` aligns the row's anchor point with the same point of the visible area. Instead
of `.top`/`.bottom`, `align()` uses `UnitPoint(x: 0.5, y: topFade / height)` and
`UnitPoint(x: 0.5, y: (height − bottomFade) / height)`, computed from the measured height, so the row's
top or bottom lands exactly on the clear band's edge. `align()` keeps re-checking until
`SelectionReveal` returns nil, as today. Alternatives: driving the `NSScrollView` offset directly
(more code, and bypasses SwiftUI's lazy loading) or padding alone (fixes only the list ends).

If the unit-point landing does not settle in a single pass on macOS 13 (the anchor maps against a frame
that differs from the measured one), `align()` stops after the scroll position stops changing, the same
exit used for rows that cannot move further, so it never oscillates.

### D4: End padding through a shared modifier
A modifier in `DesignSystem/Scrolling/` applies the list content's top and bottom padding as the dissolve
overshoot (32 and 28, scaled) plus the existing `xs`/`md`, replacing the hand-written
`.padding(.top, xs)` / `.padding(.bottom, md)` on every list under the bars. Extension lists use the same
modifier: it is scrolling infrastructure, like `edgeDissolve()`, not an extension look. Lists with a
different top padding (the emoji grid's first section) keep their inner padding and gain only the shared
outer padding.

## Risks / Trade-offs

- **The resting look changes** → The first row starts about 32pt lower and the list ends with more space.
  This is the agreed trade-off for reaching the first and last rows; verified by eye on the launcher,
  clipboard and emoji screens.
- **`scrollTo` anchor semantics differ between macOS 13 and 27** → Verified on both with the debug
  measurement in D2; the settle-or-stop exit in D3 prevents loops.
- **Grids with tall tiles** → The "taller than the band" rule keeps showing the tile's top.
- **Short lists** → A list that fits gains space at its end but no scrolling; no row is faded because the
  mask is off when nothing scrolls.
