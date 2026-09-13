#requires AutoHotkey v2.0

#include ..\lib\CaretIndicator.ahk
#include TestFramework.ahk

class CaretOverlayPainterFake {
    removed := false
    cleared := false

    RemoveWindow() {
        this.removed := true
    }

    ClearAll() {
        this.cleared := true
    }
}

class CaretOverlayLifecycleTests {
    static Run() {
        T.StartSuite("CaretOverlayLifecycle.FocusLoss")

        indicator := CaretIndicator()
        fakePainter := CaretOverlayPainterFake()
        indicator.markPainter := fakePainter
        indicator.currentMarkObj := { name: "ru", image: "dummy.png" }

        indicator.DismissCaretOverlay()

        T.AssertEqual(indicator.currentMarkObj, "", "Focus loss clears the current caret mark")
        T.Assert(fakePainter.removed, "Focus loss destroys the caret overlay window")
        T.Assert(fakePainter.cleared, "Focus loss clears cached overlay coordinates")
    }
}
