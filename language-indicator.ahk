#requires AutoHotkey v2.0
#singleinstance force

#include lib\CaretIndicator.ahk
#include lib\CursorIndicator.ahk
#include lib\SettingsManager.ahk
#include lib\utils\Merge.ahk

class LanguageIndicator {
    static Version := "0.79-kost.4"

    __New(cfg?) {
        defaultCfg := {
            caret: {
                enabled: true,
                inputCheckPeriod: 50,
                markRepaintPeriod: 16,
                markMargin: { x: 6, y: -12 },
                markScale: 2,
                opacity: 179
            },
            cursor: {
                enabled: true,
                inputCheckPeriod: 50,
                markRepaintPeriod: 6,
                markMargin: { x: 18, y: 12, useCursorSize: false },
                markScale: 2,
                opacity: 230,
                mouseIdleHideAfter: 3000
            }
        }

        this.settings := SettingsManager(defaultCfg)
        this.cfg := IsSet(cfg) ? cfg : this.settings.Load()

        this.caretIndicator := CaretIndicator(merge(CaretIndicator.DefaultConfig, this.cfg.caret))
        this.cursorIndicator := CursorIndicator(merge(CursorIndicator.DefaultConfig, this.cfg.cursor))
    }

    Run() {
        if (!this.cfg.caret.HasOwnProp("enabled") or this.cfg.caret.enabled)
            this.caretIndicator.Run()
        if (!this.cfg.cursor.HasOwnProp("enabled") or this.cfg.cursor.enabled)
            this.cursorIndicator.Run()

        this.ConfigureTray()
    }

    ConfigureTray() {
        A_TrayMenu.Delete()
        A_TrayMenu.Add("Настройки...", (*) => this.settings.Show(this.cfg))
        A_TrayMenu.Add("Перезапустить", (*) => Reload())
        A_TrayMenu.Add()
        A_TrayMenu.Add("Выход", (*) => ExitApp())
        A_TrayMenu.Default := "Настройки..."
    }
}

; Application entry point
global app := LanguageIndicator()
app.Run()

A_IconTip := "Language Indicator Cursor v" . LanguageIndicator.Version
