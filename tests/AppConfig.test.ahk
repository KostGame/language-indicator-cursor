#requires AutoHotkey v2.0

#include ..\lib\AppConfig.ahk
#include TestFramework.ahk

class AppConfigTests {
    static Run() {
        T.StartSuite("AppConfig.StableDefaults")

        cfg := CreateLanguageIndicatorDefaultConfig()

        T.Assert(cfg.caret.enabled, "Text-caret indicator is enabled by default")
        T.Assert(!cfg.cursor.enabled, "Mouse-following indicator is disabled by default")
    }
}
