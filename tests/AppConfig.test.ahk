#requires AutoHotkey v2.0

#include ..\lib\AppConfig.ahk
#include TestFramework.ahk

class AppConfigTests {
    static Run() {
        T.StartSuite("AppConfig.StableDefaults")

        cfg := CreateLanguageIndicatorDefaultConfig()

        T.Assert(cfg.caret.enabled, "Text-caret indicator is enabled by default")
        T.Assert(!cfg.cursor.enabled, "Mouse-following indicator is disabled by default")
        T.Assert(cfg.systemCursor.enabled, "System cursor language colors are enabled in 0.80 beta")
        T.AssertEqual(cfg.systemCursor.ruColor, 0xE53935, "Russian system cursor accent defaults to red")
        T.AssertEqual(cfg.systemCursor.usColor, 0x2F80ED, "English system cursor accent defaults to blue")
    }
}
