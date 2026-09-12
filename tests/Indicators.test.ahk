#requires AutoHotkey v2.0

#include ..\lib\CaretIndicator.ahk
#include ..\lib\CursorIndicator.ahk
#include TestFramework.ahk

class CaretIndicatorTests {
    static Run() {
        this.TestDefaultConfig()
        this.TestInitialization()
        this.TestGetPosition()
    }

    static TestDefaultConfig() {
        T.StartSuite("CaretIndicator.DefaultConfig")

        cfg := CaretIndicator.DefaultConfig

        T.Assert(cfg.HasOwnProp("debug"), "Config has debug property")
        T.Assert(cfg.HasOwnProp("files"), "Config has files property")
        T.Assert(cfg.HasOwnProp("markMargin"), "Config has markMargin property")
        T.Assert(cfg.HasOwnProp("markScale"), "Config has markScale property")
        T.Assert(cfg.HasOwnProp("inputCheckPeriod"), "Config has inputCheckPeriod property")
        T.Assert(cfg.HasOwnProp("markRepaintPeriod"), "Config has markRepaintPeriod property")

        T.Assert(cfg.files.HasOwnProp("folder"), "files has folder property")
        T.Assert(cfg.files.HasOwnProp("extensions"), "files has extensions property")
        T.Assert(cfg.files.HasOwnProp("capslockSuffix"), "files has capslockSuffix property")

        T.AssertEqual(cfg.files.capslockSuffix, "", "Caps Lock does not select another caret flag")
        T.Assert(cfg.files.extensions.Length == 1, "Caret indicator uses PNG flags")
        T.AssertEqual(cfg.files.extensions[1], ".png", "Caret marker is a PNG overlay")
        T.Assert(InStr(cfg.files.folder, "img\flags-png") > 0, "Caret flags come from img/flags-png")
        T.AssertEqual(cfg.markScale, 2, "Caret flags are displayed at 2x source size")
        T.AssertEqual(cfg.inputCheckPeriod, 50, "Default inputCheckPeriod is 50")
        T.AssertEqual(cfg.markRepaintPeriod, 16, "Default markRepaintPeriod is 16")
        T.AssertEqual(cfg.positionCacheTtl, 1000, "Default positionCacheTtl is 1000")
    }

    static TestInitialization() {
        T.StartSuite("CaretIndicator.Initialization")

        indicator := CaretIndicator()

        T.Assert(indicator.HasOwnProp("cfg"), "Indicator has cfg")
        T.Assert(indicator.HasOwnProp("markPainter"), "Indicator has markPainter (ImagePainter)")
        T.Assert(indicator.HasOwnProp("currentMarkObj"), "Indicator has currentMarkObj")
        T.Assert(indicator.HasOwnProp("getCachedPosition"), "Indicator has getCachedPosition")
        T.Assert(indicator.markPainter is ImagePainter, "markPainter is ImagePainter instance")
        T.AssertEqual(indicator.markPainter.scale, 2, "Caret indicator applies configured image scale")
    }

    static TestGetPosition() {
        T.StartSuite("CaretIndicator.GetPosition")

        indicator := CaretIndicator()
        pos := indicator.GetPosition()

        T.Assert(pos.HasOwnProp("left"), "Position has left property")
        T.Assert(pos.HasOwnProp("top"), "Position has top property")
        T.Assert(pos.HasOwnProp("right"), "Position has right property")
        T.Assert(pos.HasOwnProp("bottom"), "Position has bottom property")
        T.Assert(pos.HasOwnProp("w"), "Position has w (width) property")
        T.Assert(pos.HasOwnProp("h"), "Position has h (height) property")
        T.Assert(pos.HasOwnProp("detectMethod"), "Position has detectMethod property")
    }
}

class CursorIndicatorTests {
    static Run() {
        this.TestDefaultConfig()
        this.TestInitialization()
        this.TestGetPosition()
        this.TestMouseIdleVisibility()
    }

    static TestDefaultConfig() {
        T.StartSuite("CursorIndicator.DefaultConfig")

        cfg := CursorIndicator.DefaultConfig

        T.Assert(cfg.HasOwnProp("debug"), "Config has debug property")
        T.Assert(cfg.HasOwnProp("files"), "Config has files property")
        T.Assert(cfg.HasOwnProp("markMargin"), "Config has markMargin property")
        T.Assert(cfg.HasOwnProp("markScale"), "Config has markScale property")
        T.Assert(cfg.HasOwnProp("inputCheckPeriod"), "Config has inputCheckPeriod property")
        T.Assert(cfg.HasOwnProp("markRepaintPeriod"), "Config has markRepaintPeriod property")
        T.Assert(cfg.HasOwnProp("mousePositionPrediction"), "Config has mousePositionPrediction property")
        T.Assert(cfg.HasOwnProp("mouseIdleHideAfter"), "Config has mouseIdleHideAfter property")

        T.AssertEqual(cfg.files.capslockSuffix, "", "Caps Lock does not select another cursor flag")
        T.Assert(cfg.files.extensions.Length == 1, "Only PNG floating flags are supported")
        T.AssertEqual(cfg.files.extensions[1], ".png", "Cursor marker is a PNG overlay")
        T.Assert(InStr(cfg.files.folder, "img\flags-png") > 0, "Cursor flags come from img/flags-png")
        T.AssertEqual(cfg.markScale, 2, "Flags are displayed at 2x source size")
        T.AssertEqual(cfg.markMargin.useCursorSize, false, "Placement is independent of cursor type")
        T.AssertEqual(cfg.mouseIdleHideAfter, 3000, "Mouse flag hides after 3000ms idle")
        T.AssertEqual(cfg.inputCheckPeriod, 50, "Default inputCheckPeriod is 50")
        T.AssertEqual(cfg.markRepaintPeriod, 6, "Default markRepaintPeriod is 6")
    }

    static TestInitialization() {
        T.StartSuite("CursorIndicator.Initialization")

        indicator := CursorIndicator()

        T.Assert(indicator.HasOwnProp("cfg"), "Indicator has cfg")
        T.Assert(indicator.HasOwnProp("markPainter"), "Indicator has markPainter (ImagePainter)")
        T.Assert(indicator.HasOwnProp("currentMarkObj"), "Indicator has currentMarkObj")
        T.Assert(indicator.HasOwnProp("lastMouseX"), "Indicator tracks last mouse X")
        T.Assert(indicator.HasOwnProp("lastMouseY"), "Indicator tracks last mouse Y")
        T.Assert(indicator.HasOwnProp("lastMouseMoveTick"), "Indicator tracks last mouse movement time")
        T.Assert(indicator.markPainter is ImagePainter, "markPainter is ImagePainter instance")
        T.AssertEqual(indicator.markPainter.scale, 2, "Cursor indicator applies configured image scale")
    }

    static TestGetPosition() {
        T.StartSuite("CursorIndicator.GetPosition")

        indicator := CursorIndicator()
        pos := indicator.GetPosition()

        T.Assert(pos.HasOwnProp("x"), "Position has x property")
        T.Assert(pos.HasOwnProp("y"), "Position has y property")
    }

    static TestMouseIdleVisibility() {
        T.StartSuite("CursorIndicator.MouseIdleVisibility")

        indicator := CursorIndicator()
        pos := { x: 100, y: 200 }

        T.Assert(indicator.IsMouseActive(pos, 1000), "First observed mouse position is active")
        T.Assert(indicator.IsMouseActive(pos, 3999), "Mouse flag remains visible before 3s idle")
        T.Assert(!indicator.IsMouseActive(pos, 4000), "Mouse flag hides at 3s idle")
        T.Assert(indicator.IsMouseActive({ x: 101, y: 200 }, 4001), "Mouse movement makes flag visible again")
        T.AssertEqual(indicator.lastMouseMoveTick, 4001, "Mouse movement refreshes idle timer")
    }
}
