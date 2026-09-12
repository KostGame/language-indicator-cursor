#requires AutoHotkey v2.0
#singleinstance force

#include lib\CursorIndicator.ahk
#include lib\SettingsManager.ahk
#include lib\AppConfig.ahk
#include lib\utils\Merge.ahk
#include lib\runtime\ProcessIsolation.ahk

class LanguageIndicator {
    static Version := "0.79-kost.8-rc4"

    __New(cfg?) {
        defaultCfg := CreateLanguageIndicatorDefaultConfig()
        this.settings := SettingsManager(defaultCfg)
        this.cfg := IsSet(cfg) ? cfg : this.settings.Load()

        this.cursorIndicator := CursorIndicator(merge(CursorIndicator.DefaultConfig, this.cfg.cursor))
        this.caretSupervisor := CaretWorkerSupervisor()
        this.exitFn := (reason, code) => this.Shutdown()
    }

    Run() {
        ; Mouse tracking deliberately stays in the tray/main process. Caret
        ; accessibility probing runs in a separate worker so a stuck target
        ; application cannot starve the mouse timers or the tray UI.
        if (!this.cfg.cursor.HasOwnProp("enabled") or this.cfg.cursor.enabled)
            this.cursorIndicator.Run()

        if (!this.cfg.caret.HasOwnProp("enabled") or this.cfg.caret.enabled)
            this.caretSupervisor.Start()
        else
            this.caretSupervisor.Stop()

        this.settings.ConfigureTray(this.cfg)
        OnExit(this.exitFn)
    }

    Shutdown() {
        this.caretSupervisor.Stop()
        try A_IconHidden := true
    }
}

global app := LanguageIndicator()
app.Run()

A_IconTip := "Language Indicator Cursor v" . LanguageIndicator.Version
