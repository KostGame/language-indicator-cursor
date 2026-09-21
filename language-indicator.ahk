#requires AutoHotkey v2.0
#singleinstance force

#include lib\CursorIndicator.ahk
#include lib\SystemCursorColorIndicator.ahk
#include lib\SettingsManager.ahk
#include lib\AppConfig.ahk
#include lib\utils\Merge.ahk
#include lib\runtime\CaretWorkerRuntime.ahk

class LanguageIndicator {
    static Version := "0.80-kost.2-rc1"

    __New(cfg?) {
        defaultCfg := CreateLanguageIndicatorDefaultConfig()
        this.settings := SettingsManager(defaultCfg)
        this.cfg := IsSet(cfg) ? cfg : this.settings.Load()

        this.cursorIndicator := CursorIndicator(merge(CursorIndicator.DefaultConfig, this.cfg.cursor))
        this.systemCursorIndicator := this.cfg.HasOwnProp("systemCursor")
            ? SystemCursorColorIndicator(merge(SystemCursorColorIndicator.DefaultConfig, this.cfg.systemCursor))
            : ""
        this.caretSupervisor := CaretWorkerSupervisor()
        this.caretWatchdogFn := ObjBindMethod(this.caretSupervisor, "Watchdog")
        this.exitFn := (reason, code) => this.Shutdown()
    }

    Run() {
        if (!this.cfg.cursor.HasOwnProp("enabled") or this.cfg.cursor.enabled)
            this.cursorIndicator.Run()

        if (this.systemCursorIndicator != "" and this.cfg.systemCursor.enabled)
            this.systemCursorIndicator.Run()

        if (!this.cfg.caret.HasOwnProp("enabled") or this.cfg.caret.enabled) {
            this.caretSupervisor.Start()
            SetTimer(this.caretWatchdogFn, 1000)
        } else {
            this.caretSupervisor.Stop()
        }

        this.settings.ConfigureTray(this.cfg)
        OnExit(this.exitFn)
    }

    Shutdown() {
        SetTimer(this.caretWatchdogFn, 0)
        this.caretSupervisor.Stop()
        if this.systemCursorIndicator != ""
            this.systemCursorIndicator.Stop()
        try A_IconHidden := true
    }
}

global app := LanguageIndicator()
app.Run()

A_IconTip := "Language Indicator Cursor v" . LanguageIndicator.Version
