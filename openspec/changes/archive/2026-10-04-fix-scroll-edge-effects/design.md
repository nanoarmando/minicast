## Context

See `proposal.md`. Current fork behavior (read-only analysis):

- The palette screen is wrapped in `safeAreaInset(.top) { header }` and `safeAreaInset(.bottom) { bottomBar }`
  (`RootPaletteView`); the header and bottom bar have no background. `docs/ui.md` states the separation comes
  only from `edgeDissolve()`.
- `EdgeDissolveMask` returns a single opaque stop unless `canScroll` is true; `canScroll` is only set from
  `onScrollMetricsChange`.
- `ScrollObserverView` (in `ScrollObservation.swift`) is a `.background` probe that looks for the sibling
  `NSScrollView` whose window-space rect overlaps its own. `attach()` retries at most 10 times through
  chained zero-delay main-queue hops and returns nil while its own rect is zero. When the retries are spent,
  `layout()` and `updateNSView` never re-attach, so the probe stays detached for the view's lifetime.
- `NativeScrollerHider` (in `ThinScrollbar.swift`) finds its scroll view reliably through
  `enclosingScrollView` from inside the content.

## Goals / Non-Goals

**Goals:** a probe that always attaches once the scroll view exists; a mask fallback that never leaves
content opaque under the bars; no change to call sites or to the visual design.

**Non-Goals:** adding backgrounds to the bars; redesigning the dissolve math; reintroducing Liquid Glass.

## Decisions

### 1. Self-healing attach
`ScrollObserverView` re-attempts `attach()` whenever it has no scroll view and its geometry or hosting
changes: in `layout()`, in `viewDidMoveToSuperview`/`viewDidMoveToWindow`, and from `updateNSView`. The
retry budget resets on each of those events, and remaining retries are spaced with a short
`asyncAfter` delay instead of same-instant hops. Once attached, behavior is unchanged. If the attached
scroll view leaves the hierarchy, the observer detaches and can attach again.
- Alternative: move the probe inside the scroll content and use `enclosingScrollView` (as
  `NativeScrollerHider` does). More robust, but it changes the helper's placement contract for every call
  site. Kept as the fallback plan if Decision 1 does not attach reliably on both systems.

### 2. Static fallback for the dissolve
Before metrics arrive, `EdgeDissolveMask` uses the same band geometry with the faded state (as if content
were hidden past both edges), instead of a fully opaque stop. When metrics arrive and the list cannot
scroll, the mask becomes fully opaque as today. `OverflowFade` gets the same fallback only if it has the same
opaque-until-measured behavior.

### 3. Verification hooks
No new tests. Manual verification on both Macs covers each surface listed in the proposal. A temporary
debug log of probe attach results may be used during development and is removed before finishing.

## Risks / Trade-offs

- [The overlap heuristic picks the wrong scroll view, for example a text editor inside a palette screen] →
  Keep the existing overlap threshold; verify the AI screen with the composer open.
- [The static fallback fades a short list for one frame before metrics prove it cannot scroll] →
  One-frame flicker at most; acceptable.
- [The probe's frame never matches the scroll view on one OS] → Switch to the inside-the-content approach
  (Decision 1 alternative).

## Migration Plan

Code-only change; rebuild and install. Rollback: revert the commit.
