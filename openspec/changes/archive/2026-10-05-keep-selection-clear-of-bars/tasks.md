## 1. Measure

- [x] 1.1 Measure rows and the clear band on the full frame `edgeDissolve` masks (D2), which replaced
  the runtime log

## 2. Shared scrolling primitives

- [x] 2.1 Expose the dissolve band lengths from `EdgeDissolve.swift` and make the mask read them (D1)
- [x] 2.2 Change `SelectionReveal.edge` to take top and bottom limits of the clear band (D2)
- [x] 2.3 Make `SelectionFollowing.align()` compute the clear band from the shared band lengths and land
  rows with unit-point anchors, keeping the settle-or-stop exit (D3)
- [x] 2.4 Add the shared end-padding modifier (D4)

## 3. Lists

- [x] 3.1 Replace the top/bottom content padding with the shared modifier in every list that uses
  `edgeDissolve()` and `scrollFollowsSelection`: launcher, clipboard, calculator history, file search,
  emoji, calendar schedule, rooms, room picker, uninstall, chat history, extension list, grid and form

## 4. Verify

- [x] 4.1 Update `Tests/scroll-reveal-test.swift` for the clear-band limits, including a row inside the
  faded band, a row under the bar and a row taller than the clear band
- [x] 4.2 Check keyboard navigation down to the last row and back to the first on every listed screen, at
  two interface sizes, on macOS 27 and macOS 13
- [x] 4.3 Run `./Scripts/run-tests.sh`, the lint and the Debug build with no new warnings

## 5. Docs

- [x] 5.1 Update `docs/ui.md` (edge dissolve section) with the selection clearance and the end padding
