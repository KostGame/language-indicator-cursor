#requires AutoHotkey v2.0
#singleinstance force

#include lib\CaretIndicator.ahk
#include lib\CursorIndicator.ahk
#include lib\utils\Merge.ahk

class LanguageIndicator {
    static Version := "0.79-kost.3"

    __New(cfg?) {
        defaultCfg := {
            caret: {
                enabled: true,
                inputCheckPeriod: 50,
                markRepaintPeriod: 16,
                markMargin: { x: 5, y: -1 },
                markScale: 2
            },
            cursor: {
                enabled: true,
                inputCheckPeriod: 50,
                markRepaintPeriod: 6,
                markMargin: { x: 18, y: 12, useCursorSize: false },
                markScale: 2,
                mouseIdleHideAfter: 3000
            }
        }

        this.cfg := IsSet(cfg) ? cfg : defaultCfg

        this.caretIndicator := CaretIndicator(merge(CaretIndicator.DefaultConfig, this.cfg.caret))
        this.cursorIndicator := CursorIndicator(merge(CursorIndicator.DefaultConfig, this.cfg.cursor))
    }

    Run() {
        if (!this.cfg.caret.HasOwnProp("enabled") or this.cfg.caret.enabled)
            this.caretIndicator.Run()
        if (!this.cfg.cursor.HasOwnProp("enabled") or this.cfg.cursor.enabled)
            this.cursorIndicator.Run()
    }
}

; Application entry point
global app := LanguageIndicator()
app.Run()

A_IconTip := "Language Indicator Cursor v" . LanguageIndicator.Version
