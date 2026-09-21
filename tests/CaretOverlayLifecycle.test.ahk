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
        return true
    }

    ClearAll() {
        this.cleared := true
    }
}

class CaretOverlayLifecycleTests {
    static Run() {
        this.TestFocusLoss()
        this.TestLargeJumpPolicy()
        this.TestCleanupContract()
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
        T.AssertEqual(painter.largeMoveThreshold, 32, "Caret large-jump threshold is 32px")
        T.Assert(painter.flushOnRebuild, "Caret destructive rebuilds flush DWM before repaint")

        painter.prev.x := 100
        painter.prev.y := 100
        painter.current.x := 120
        painter.current.y := 118
        T.Assert(!painter._isLargeMove(), "Normal typing movement keeps the fast hide/move path")

        painter.current.x := 132
        painter.current.y := 100
        T.Assert(painter._isLargeMove(), "32px horizontal jump triggers a rebuild")

        painter.current.x := 100
        painter.current.y := 132
        T.Assert(painter._isLargeMove(), "32px vertical jump triggers a rebuild")
    }

    static TestCleanupContract() {
        T.StartSuite("CaretOverlayLifecycle.CleanupContract")

        painter := ImagePainter()
        painter.windowTitle := "LIC-Caret-Cleanup-Contract-" . A_TickCount

        cleanup := painter.PurgeOwnedOverlayWindows(0, false)

        T.AssertEqual(cleanup.found, 0, "Cleanup reports no unrelated overlay HWNDs for a unique title")
        T.AssertEqual(cleanup.destroyed, 0, "Cleanup destroys nothing when no overlay exists")
        T.AssertEqual(cleanup.remaining, 0, "Cleanup leaves no unresolved overlay HWNDs")
        T.Assert(painter.RemoveWindow(false), "Removing an already-absent overlay succeeds")
        T.Assert(painter._destroyNativeWindow(0), "Destroy helper treats an already-dead HWND as clean")
    }
}
