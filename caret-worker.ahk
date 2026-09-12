#requires AutoHotkey v2.0
#singleinstance off

#include lib\CaretIndicator.ahk
#include lib\SettingsManager.ahk
#include lib\AppConfig.ahk
#include lib\utils\Merge.ahk
#include lib\runtime\ProcessIsolation.ahk

A_IconHidden := true

generation := GetFirstCommandLineArg()
if generation == ""
    ExitApp()

defaultCfg := CreateLanguageIndicatorDefaultConfig()
settings := SettingsManager(defaultCfg)
cfg := settings.Load()

if (cfg.caret.HasOwnProp("enabled") and !cfg.caret.enabled)
    ExitApp()

heartbeat := CaretWorkerHeartbeat(generation)
caretIndicator := CaretIndicator(merge(CaretIndicator.DefaultConfig, cfg.caret))

OnExit((*) => heartbeat.Stop())
heartbeat.Start()
caretIndicator.Run()
