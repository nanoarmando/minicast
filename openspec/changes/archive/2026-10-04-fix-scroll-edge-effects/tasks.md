## 1. Implementation

- [x] 1.1 Make `ScrollObserverView` re-attach while detached on layout, hierarchy changes and `updateNSView`, with a reset retry budget spaced by a short delay, and detach cleanly if its scroll view leaves the hierarchy
- [x] 1.2 Give `EdgeDissolveMask` a static faded fallback before metrics arrive; apply the same fallback to `OverflowFade` if it is opaque until measured
- [x] 1.3 If the probe still fails to attach on either system, switch the helper to an inside-the-content probe using `enclosingScrollView` (not needed: the sibling probe attaches reliably once retries are spaced and reset)

## 2. Verification

- [x] 2.1 Debug and universal Release builds compile with no errors and no new warnings; `./Scripts/run-tests.sh` passes
- [x] 2.2 On the main Mac and the 2017 Mac: rows dissolve under both bars in the launcher, clipboard, file search, emoji, chat history and an extension list; the thin scrollbar appears; arrow-key navigation keeps the selection visible; a streaming AI reply follows the end; Settings and popup overflow fades work
