#requires AutoHotkey v2.0

#include ..\lib\SettingsManager.ahk
#include TestFramework.ahk

class SettingsManagerTests {
    static Run() {
        T.StartSuite("SettingsManager.TrayMenu")

        defaultCfg := {
            cursor: {
                enabled: true,
                opacity: 230,
                markMargin: { x: 18, y: 12, useCursorSize: false },
                mouseIdleHideAfter: 3000
            },
            caret: {
                enabled: true,
                opacity: 179,
                markMargin: { x: 6, y: -12 }
            },
            systemCursor: {
                enabled: true,
                inputCheckPeriod: 30,
                ruColor: 0xE53935,
                usColor: 0x2F80ED,
                alphaThreshold: 48
            }
        }

        manager := SettingsManager(defaultCfg)
        mouseSubmenu := manager.BuildIndicatorMenu("Mouse", defaultCfg.cursor, true, "Показывать у мыши")
        caretSubmenu := manager.BuildIndicatorMenu("Caret", defaultCfg.caret, false, "Показывать в поле ввода")
        systemCursorSubmenu := manager.BuildSystemCursorMenu(defaultCfg.systemCursor)

        T.Assert(mouseSubmenu != "", "Mouse tray submenu builds without Menu/local-variable collision")
        T.Assert(caretSubmenu != "", "Caret tray submenu builds without Menu/local-variable collision")
        T.Assert(systemCursorSubmenu != "", "System cursor color submenu builds")
    }
}
