#requires AutoHotkey v2.0

#include TestFramework.ahk
#include ..\lib\CaretIndicator.ahk
#include ..\lib\CursorIndicator.ahk

RunIndicatorTests() {
    TestCaretIndicatorDefaultConfig()
    TestCaretIndicatorInitialization()
    TestCaretIndicatorGetPosition()
    TestCursorIndicatorDefaultConfig()
    TestCursorIndicatorInitialization()
    TestCursorIndicatorGetPosition()
    TestCursorIndicatorMouseIdleVisibility()
    TestCursorIndicatorLanguageChangeWake()
    TestSafeCaretMsaaPointerContract()
}

TestCaretIndicatorDefaultConfig() {
    tf := TestFramework("CaretIndicator.DefaultConfig")
    cfg := CaretIndicator.DefaultConfig
    tf.AssertTrue(cfg.HasOwnProp("debug"), "Config has debug property")
    tf.AssertTrue(cfg.HasOwnProp("files"), "Config has files property")
    tf.AssertTrue(cfg.HasOwnProp("markMargin"), "Config has markMargin property")
    tf.AssertTrue(cfg.HasOwnProp("markScale"), "Config has markScale property")
    tf.AssertTrue(cfg.HasOwnProp("opacity"), "Config has opacity property")
    tf.AssertTrue(cfg.HasOwnProp("inputCheckPeriod"), "Config has inputCheckPeriod property")
    tf.AssertTrue(cfg.HasOwnProp("markRepaintPeriod"), "Config has markRepaintPeriod property")
    tf.AssertTrue(cfg.files.HasOwnProp("folder"), "files has folder property")
    tf.AssertTrue(cfg.files.HasOwnProp("extensions"), "files has extensions property")
    tf.AssertTrue(cfg.files.HasOwnProp("capslockSuffix"), "files has capslockSuffix property")
    tf.AssertEqual("", cfg.files.capslockSuffix, "Caps Lock does not select another caret flag")
    tf.AssertEqual(".png", cfg.files.extensions[1], "Caret indicator uses PNG flags")
    tf.AssertEqual("png", SubStr(cfg.files.extensions[1], 2), "Caret marker is a PNG overlay")
    tf.AssertTrue(InStr(cfg.files.folder, "img\flags-png"), "Caret flags come from img/flags-png")
    tf.AssertEqual(2, cfg.markScale, "Caret flags are displayed at 2x source size")
    tf.AssertEqual(179, cfg.opacity, "Caret flag defaults to about 70 percent opacity")
    tf.AssertEqual(-12, cfg.markMargin.y, "Caret flag is raised above typed text by default")
    tf.AssertEqual(20, cfg.inputCheckPeriod, "Default inputCheckPeriod is 20")
    tf.AssertEqual(16, cfg.markRepaintPeriod, "Default markRepaintPeriod is 16")
    tf.AssertEqual(1000, cfg.positionCacheTtl, "Default positionCacheTtl is 1000")
    tf.Report()
}

TestCaretIndicatorInitialization() {
    tf := TestFramework("CaretIndicator.Initialization")
    indicator := CaretIndicator()
    tf.AssertTrue(indicator.HasOwnProp("cfg"), "Indicator has cfg")
    tf.AssertTrue(indicator.HasOwnProp("markPainter"), "Indicator has markPainter (ImagePainter)")
    tf.AssertTrue(indicator.HasOwnProp("currentMarkObj"), "Indicator has currentMarkObj")
    tf.AssertTrue(indicator.HasOwnProp("getCachedPosition"), "Indicator has getCachedPosition")
    tf.AssertTrue(indicator.markPainter is ImagePainter, "markPainter is ImagePainter instance")
    tf.AssertEqual(2, indicator.markPainter.scale, "Caret indicator applies configured image scale")
    tf.AssertEqual(179, indicator.markPainter.opacity, "Caret indicator applies configured opacity")
    tf.Report()
}

TestCaretIndicatorGetPosition() {
    tf := TestFramework("CaretIndicator.GetPosition")
    indicator := CaretIndicator()
    pos := indicator.GetPosition()
    tf.AssertTrue(pos.HasOwnProp("left"), "Position has left property")
    tf.AssertTrue(pos.HasOwnProp("top"), "Position has top property")
    tf.AssertTrue(pos.HasOwnProp("right"), "Position has right property")
    tf.AssertTrue(pos.HasOwnProp("bottom"), "Position has bottom property")
    tf.AssertTrue(pos.HasOwnProp("w"), "Position has w (width) property")
    tf.AssertTrue(pos.HasOwnProp("h"), "Position has h (height property)")
    tf.AssertTrue(pos.HasOwnProp("detectMethod"), "Position has detectMethod property")
    tf.Report()
}

TestCursorIndicatorDefaultConfig() {
    tf := TestFramework("CursorIndicator.DefaultConfig")
    cfg := CursorIndicator.DefaultConfig
    tf.AssertTrue(cfg.HasOwnProp("debug"), "Config has debug property")
    tf.AssertTrue(cfg.HasOwnProp("files"), "Config has files property")
    tf.AssertTrue(cfg.HasOwnProp("markMargin"), "Config has markMargin property")
    tf.AssertTrue(cfg.HasOwnProp("markScale"), "Config has markScale property")
    tf.AssertTrue(cfg.HasOwnProp("opacity"), "Config has opacity property")
    tf.AssertTrue(cfg.HasOwnProp("inputCheckPeriod"), "Config has inputCheckPeriod property")
    tf.AssertTrue(cfg.HasOwnProp("markRepaintPeriod"), "Config has markRepaintPeriod property")
    tf.AssertTrue(cfg.HasOwnProp("mousePositionPrediction"), "Config has mousePositionPrediction property")
    tf.AssertTrue(cfg.HasOwnProp("mouseIdleHideAfter"), "Config has mouseIdleHideAfter property")
    tf.AssertEqual("", cfg.files.capslockSuffix, "Caps Lock does not select another cursor flag")
    tf.AssertEqual(1, cfg.files.extensions.Length, "Only PNG floating flags are supported")
    tf.AssertEqual(".png", cfg.files.extensions[1], "Cursor marker is a PNG overlay")
    tf.AssertTrue(InStr(cfg.files.folder, "img\flags-png"), "Cursor flags come from img/flags-png")
    tf.AssertEqual(2, cfg.markScale, "Flags are displayed at 2x source size")
    tf.AssertEqual(230, cfg.opacity, "Mouse flag defaults to about 90 percent opacity")
    tf.AssertEqual(0, cfg.cursorSize, "Placement is independent of cursor type")
    tf.AssertEqual(3000, cfg.mouseIdleHideAfter, "Mouse flag hides after 3000ms idle")
    tf.AssertEqual(20, cfg.inputCheckPeriod, "Default inputCheckPeriod is 20")
    tf.AssertEqual(6, cfg.markRepaintPeriod, "Default markRepaintPeriod is 6")
    tf.Report()
}

TestCursorIndicatorInitialization() {
    tf := TestFramework("CursorIndicator.Initialization")
    indicator := CursorIndicator()
    tf.AssertTrue(indicator.HasOwnProp("cfg"), "Indicator has cfg")
    tf.AssertTrue(indicator.HasOwnProp("markPainter"), "Indicator has markPainter (ImagePainter)")
    tf.AssertTrue(indicator.HasOwnProp("currentMarkObj"), "Indicator has currentMarkObj")
    tf.AssertTrue(indicator.HasOwnProp("lastMouseX"), "Indicator tracks last mouse X")
    tf.AssertTrue(indicator.HasOwnProp("lastMouseY"), "Indicator tracks last mouse Y")
    tf.AssertTrue(indicator.HasOwnProp("lastMouseMovementAt"), "Indicator tracks last mouse movement time")
    tf.AssertTrue(indicator.HasOwnProp("lastValidFlagCode"), "Indicator tracks last valid flag code")
    tf.AssertTrue(indicator.markPainter is ImagePainter, "markPainter is ImagePainter instance")
    tf.AssertEqual(2, indicator.markPainter.scale, "Cursor indicator applies configured image scale")
    tf.AssertEqual(230, indicator.markPainter.opacity, "Cursor indicator applies configured opacity")
    tf.Report()
}

TestCursorIndicatorGetPosition() {
    tf := TestFramework("CursorIndicator.GetPosition")
    indicator := CursorIndicator()
    pos := indicator.GetPosition()
    tf.AssertTrue(pos.HasOwnProp("x"), "Position has x property")
    tf.AssertTrue(pos.HasOwnProp("y"), "Position has y property")
    tf.Report()
}

TestCursorIndicatorMouseIdleVisibility() {
    tf := TestFramework("CursorIndicator.MouseIdleVisibility")
    indicator := CursorIndicator()
    baseTick := 10000

    tf.AssertTrue(indicator.ObserveMouseActivity(100, 100, baseTick), "First observed mouse position is active")
    tf.AssertTrue(indicator.ObserveMouseActivity(100, 100, baseTick + 2999), "Mouse flag remains visible before 3s idle")
    tf.AssertFalse(indicator.ObserveMouseActivity(100, 100, baseTick + 3000), "Mouse flag hides at 3s idle")
    tf.AssertTrue(indicator.ObserveMouseActivity(101, 100, baseTick + 3001), "Mouse movement makes flag visible again")
    tf.AssertEqual(baseTick + 3001, indicator.lastMouseMovementAt, "Mouse movement refreshes idle timer")
    tf.Report()
}

TestCursorIndicatorLanguageChangeWake() {
    tf := TestFramework("CursorIndicator.LanguageChangeWake")
    indicator := CursorIndicator()
    indicator.ObserveMouseActivity(100, 100, 10000)

    tf.AssertFalse(indicator.ObserveMouseActivity(100, 100, 14000), "Mouse is idle before layout change")
    indicator.ObserveLanguage("ru", 14000)
    tf.AssertTrue(indicator.ObserveMouseActivity(100, 100, 14001), "First valid language wakes indicator")
    tf.AssertEqual(14000, indicator.lastMouseMovementAt, "Language observation resets idle timeout")

    indicator.ObserveLanguage("ru", 14500)
    tf.AssertEqual(14000, indicator.lastMouseMovementAt, "Same language does not repeatedly reset idle timeout")

    indicator.ObserveLanguage("us", 15000)
    tf.AssertTrue(indicator.ObserveMouseActivity(100, 100, 15001), "RU to EN change wakes indicator")
    tf.AssertEqual(15000, indicator.lastMouseMovementAt, "Language change refreshes idle timestamp")
    tf.Report()
}

TestSafeCaretMsaaPointerContract() {
    tf := TestFramework("GetCaretRectSafe.MsaaPointerContract")
    source := FileRead(A_ScriptDir . "\..\lib\detection\GetCaretRectSafe.ahk")
    tf.AssertTrue(InStr(source, 'pAcc := 0'), "MSAA path receives IAccessible into a raw pointer variable")
    tf.AssertTrue(InStr(source, '"ptr*", &pAcc'), "AccessibleObjectFromWindow writes through a pointer VarRef")
    tf.AssertTrue(InStr(source, 'ComValue(9, pAcc, 1)'), "Raw IAccessible pointer is wrapped only after validation")
    tf.AssertFalse(InStr(source, '!acc.Ptr'), "MSAA path does not dereference non-existent ComObject.Ptr")
    tf.Report()
}
