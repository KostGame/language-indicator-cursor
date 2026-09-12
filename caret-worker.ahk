#requires AutoHotkey v2.0
#singleinstance off

#include lib\CaretIndicator.ahk
#include lib\SettingsManager.ahk
#include lib\AppConfig.ahk
#include lib\utils\Merge.ahk

A_IconHidden := true

defaultCfg := CreateLanguageIndicatorDefaultConfig()
settings := SettingsManager(defaultCfg)
cfg := settings.Load()

if (cfg.caret.HasOwnProp("enabled") and !cfg.caret.enabled)
    ExitApp()

caretWorkerIndicator := CaretIndicator(merge(CaretIndicator.DefaultConfig, cfg.caret))
caretWorkerIndicator.Run()
