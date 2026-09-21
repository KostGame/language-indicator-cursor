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
        this.TestVerifiedNativeDestroy()
        this.TestOrphanSweep()
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

    static TestVerifiedNativeDestroy() {
        T.StartSuite("CaretOverlayLifecycle.VerifiedNativeDestroy")

        painter := ImagePainter()
        painter.windowTitle := "LIC-Caret-Destroy-Test-" . A_TickCount . "-" . Random(1000, 9999)
        guiObj := Gui("-Caption +ToolWindow")
        guiObj.Title := painter.windowTitle
        guiObj.Show("NA x-32000 y-32000 w10 h10")

        painter.window := guiObj
        painter.windowVisible := true
        hwnd := guiObj.Hwnd

        T.Assert(painter._isNativeWindow(hwnd), "Native overlay HWND exists before removal")
        removed := painter.RemoveWindow(false)

        T.Assert(removed, "RemoveWindow reports verified native destruction")
        T.Assert(!painter._isNativeWindow(hwnd), "Native HWND is gone after removal")
        T.AssertEqual(painter.window, "", "AHK window reference is forgotten only after verified destruction")

        try guiObj.Destroy()
    }

    static TestOrphanSweep() {
        T.StartSuite("CaretOverlayLifecycle.OrphanSweep")

        painter := ImagePainter()
        painter.windowTitle := "LIC-Caret-Orphan-Test-" . A_TickCount . "-" . Random(1000, 9999)

        orphan1 := Gui("-Caption +ToolWindow")
        orphan1.Title := painter.windowTitle
        orphan1.Show("NA x-32000 y-32000 w10 h10")
        hwnd1 := orphan1.Hwnd

        orphan2 := Gui("-Caption +ToolWindow")
        orphan2.Title := painter.windowTitle
        orphan2.Show("NA x-31980 y-32000 w10 h10")
        hwnd2 := orphan2.Hwnd

        try {
            cleanup := painter.PurgeOwnedOverlayWindows(0, false)

            T.Assert(cleanup.found >= 2, "Orphan sweep finds duplicate overlay HWNDs owned by this process")
            T.Assert(cleanup.destroyed >= 2, "Orphan sweep destroys duplicate overlay HWNDs")
            T.AssertEqual(cleanup.remaining, 0, "Orphan sweep leaves no same-title overlay HWNDs behind")
            T.Assert(!painter._isNativeWindow(hwnd1), "First orphan HWND is destroyed")
            T.Assert(!painter._isNativeWindow(hwnd2), "Second orphan HWND is destroyed")
        } finally {
            try orphan1.Destroy()
            try orphan2.Destroy()
        }
    }
}
