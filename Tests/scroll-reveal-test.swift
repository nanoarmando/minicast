import CoreGraphics
import Foundation

/// A row inside the clear band may not scroll; one faded or under a bar must.
@main
@MainActor
struct SelectionRevealTests {
    static var failures = 0
    static var passes = 0

    /// The palette's real proportions: a 469pt frame, 96pt faded on top, 64pt at the bottom.
    static let top: CGFloat = 96
    static let bottom: CGFloat = 469 - 64
    static let rowHeight: CGFloat = 36

    static func expect(
        _ actual: SelectionReveal.Edge?, _ expected: SelectionReveal.Edge?, _ message: String
    ) {
        if actual == expected {
            passes += 1
        } else {
            failures += 1
            print("FAIL: \(message) — got \(String(describing: actual)), want \(expected as Any)")
        }
    }

    /// A row `rowHeight` tall whose top sits at `top`, measured from the full frame's top.
    static func edge(rowTop row: CGFloat, height: CGFloat = rowHeight) -> SelectionReveal.Edge? {
        SelectionReveal.edge(rowTop: row, rowBottom: row + height, top: top, bottom: bottom)
    }

    static func main() {
        rowsInsideTheClearBandStayPut()
        rowsInAFadedBandScroll()
        rowsUnderABarScroll()
        aRowTallerThanTheClearBand()

        print("\(passes) passed, \(failures) failed")
        if failures > 0 { exit(1) }
    }

    // MARK: - Leaving a clear row alone

    static func rowsInsideTheClearBandStayPut() {
        expect(edge(rowTop: top), nil, "a row flush with the band's top needs no scroll")
        expect(edge(rowTop: 220), nil, "nor does a row in the middle")
        expect(edge(rowTop: bottom - rowHeight), nil, "nor one flush with the bottom limit")
        // Rounding must not churn: geometry arrives in fractional points.
        expect(edge(rowTop: top - 0.3), nil, "a third of a point into the top fade is still clear")
        expect(edge(rowTop: bottom - rowHeight + 0.3), nil, "and so is a third into the bottom")
    }

    // MARK: - Rows the dissolve still fades

    static func rowsInAFadedBandScroll() {
        expect(edge(rowTop: top - 1), .top, "a row a point into the top fade aligns to the top")
        expect(edge(rowTop: 70), .top, "so does one past the header, inside the overshoot")
        expect(edge(rowTop: bottom - rowHeight + 1), .bottom, "a point into the bottom fade aligns")
        expect(edge(rowTop: bottom - 10), .bottom, "and so does one inside the bottom overshoot")
    }

    // MARK: - Rows hidden by a bar

    static func rowsUnderABarScroll() {
        expect(edge(rowTop: 10), .top, "a row under the header aligns to the top")
        expect(edge(rowTop: -4000), .top, "and one far above, after a jump to the list's start")
        expect(edge(rowTop: 440), .bottom, "a row under the bottom bar aligns to the bottom")
        expect(edge(rowTop: 4000), .bottom, "and so does one far below it")
    }

    // MARK: - Rows that cannot fit

    static func aRowTallerThanTheClearBand() {
        let tall = bottom - top + 100
        // Only its start can show, so aligning the top is the end state, not the start of a loop.
        expect(edge(rowTop: top, height: tall), nil, "a too-tall row pinned at the top is settled")
        expect(edge(rowTop: top - 50, height: tall), .top, "one scrolled past its top is pulled back")
        expect(edge(rowTop: top + 20, height: tall), .top, "and one hanging below the top is too")
    }
}
