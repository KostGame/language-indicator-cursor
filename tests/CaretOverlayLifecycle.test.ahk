#requires AutoHotkey v2.0

#include ..\lib\CaretIndicator.ahk
#include TestFramework.ahk

class CaretOverlayPainterFake {
    removed := false
    cleared := false
    flushRequested := false

    RemoveWindow(flushComposition := false) {
        this.removed := true
        this.flushRequested := flushComposition
    }

    ClearAll() {
        this.cleared := true
    }
}

class CaretOverlayLifecycleTests {
    static Run() {
        this.TestFocusLoss()
        this.TestLargeJumpPolicy()
    }

    static TestFocusLoss() {
        T.StartSuite("CaretOverlayLifecycle.FocusLoss")

        indicator := CaretIndicator()
        fakePainter := CaretOverlayPainterFake()
        indicator.markPainter := fakePainter
        indicator.currentMarkObj := { name: "ru", image: "dummy.png" }

        indicator.DismissCaretOverlay()

        T.AssertEqual(indicator.currentMarkObj, "", "Focus loss clears the current caret mark")
        T.Assert(fakePainter.removed, "Focus loss destroys the caret overlay window")
        T.Assert(fakePainter.flushRequested, "Focus loss flushes the destroyed overlay through DWM")
        T.Assert(fakePainter.cleared, "Focus loss clears cached overlay coordinates")
    }

    static TestLargeJumpPolicy() {
        T.StartSuite("CaretOverlayLifecycle.LargeJump")

        indicator := CaretIndicator()
        painter := indicator.markPainter

        T.Assert(painter.rebuildOnLargeMove, "Caret overlay rebuilds instead of teleporting on large jumps")
        T.AssertEqual(painter.largeMoveThreshold, 64, "Caret large-jump threshold is 64px")

        painter.prev.x := 100
        painter.prev.y := 100
        painter.current.x := 120
        painter.current.y := 118
        T.Assert(!painter._isLargeMove(), "Normal typing movement keeps the fast hide/move path")

        painter.current.x := 400
        painter.current.y := 100
        T.Assert(painter._isLargeMove(), "Large horizontal Chromium jump triggers a rebuild")

        painter.current.x := 100
        painter.current.y := 220
        T.Assert(painter._isLargeMove(), "Large vertical Chromium jump triggers a rebuild")
    }
}
