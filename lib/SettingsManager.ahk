#requires AutoHotkey v2.0

; Persistent per-user settings with a tray-only UI.
; Settings are stored under %APPDATA% so the application directory can stay read-only.
class SettingsManager {
    static AppFolder := "LanguageIndicatorCursor"

    __New(defaultCfg) {
        this.defaultCfg := defaultCfg
        this.settingsDir := A_AppData . "\" . SettingsManager.AppFolder
        this.path := this.settingsDir . "\settings.ini"
    }

    Load() {
        cfg := this.defaultCfg

        cfg.cursor.enabled := this.ReadBool("Mouse", "Enabled", cfg.cursor.enabled)
        cfg.cursor.opacity := SettingsManager.PercentToAlpha(
            this.ReadInt("Mouse", "OpacityPercent", SettingsManager.AlphaToPercent(cfg.cursor.opacity), 20, 100)
        )
        cfg.cursor.markMargin := {
            x: this.ReadInt("Mouse", "OffsetX", cfg.cursor.markMargin.x, -200, 200),
            y: this.ReadInt("Mouse", "OffsetY", cfg.cursor.markMargin.y, -200, 200),
            useCursorSize: false
        }
        idleSeconds := this.ReadInt("Mouse", "HideAfterSeconds", Round(cfg.cursor.mouseIdleHideAfter / 1000), 0, 3600)
        cfg.cursor.mouseIdleHideAfter := idleSeconds * 1000

        cfg.caret.enabled := this.ReadBool("Caret", "Enabled", cfg.caret.enabled)
        cfg.caret.opacity := SettingsManager.PercentToAlpha(
            this.ReadInt("Caret", "OpacityPercent", SettingsManager.AlphaToPercent(cfg.caret.opacity), 20, 100)
        )
        cfg.caret.markMargin := {
            x: this.ReadInt("Caret", "OffsetX", cfg.caret.markMargin.x, -200, 200),
            y: this.ReadInt("Caret", "OffsetY", cfg.caret.markMargin.y, -200, 200)
        }

        if cfg.HasOwnProp("systemCursor")
            cfg.systemCursor.enabled := this.ReadBool("SystemCursor", "Enabled", cfg.systemCursor.enabled)

        return cfg
    }

    ConfigureTray(cfg) {
        A_TrayMenu.Delete()

        mouseMenu := this.BuildIndicatorMenu("Mouse", cfg.cursor, true, "Показывать у мыши")
        caretMenu := this.BuildIndicatorMenu("Caret", cfg.caret, false, "Показывать в поле ввода")

        A_TrayMenu.Add("У мыши", mouseMenu)
        A_TrayMenu.Add("В поле ввода", caretMenu)

        if cfg.HasOwnProp("systemCursor") {
            systemCursorMenu := this.BuildSystemCursorMenu(cfg.systemCursor)
            A_TrayMenu.Add("Цвет системных курсоров", systemCursorMenu)
        }

        A_TrayMenu.Add()
        A_TrayMenu.Add("Перезапустить индикатор", (*) => this.ReloadClean())
        A_TrayMenu.Add("Открыть папку настроек", (*) => this.OpenSettingsFolder())
        A_TrayMenu.Add()
        A_TrayMenu.Add("Выход", (*) => this.ExitClean())
    }

    BuildSystemCursorMenu(cfg) {
        cursorColorMenu := Menu()
        enabledLabel := "Красный RU / синий EN"
        cursorColorMenu.Add(enabledLabel, ObjBindMethod(this, "SetBoolAndReload", "SystemCursor", "Enabled", !cfg.enabled))
        if cfg.enabled
            cursorColorMenu.Check(enabledLabel)
        cursorColorMenu.Add()
        cursorColorMenu.Add("Эксперимент 0.80 beta: Arrow, Hand, IBeam, resize и др.", (*) => 0)
        cursorColorMenu.Disable("Эксперимент 0.80 beta: Arrow, Hand, IBeam, resize и др.")
        return cursorColorMenu
    }

    BuildIndicatorMenu(section, cfg, includeIdle, enabledLabel) {
        ; AutoHotkey v2 identifiers are case-insensitive. Do not name this local
        ; variable `menu`, because that shadows the built-in Menu class on RHS.
        indicatorMenu := Menu()

        indicatorMenu.Add(enabledLabel, ObjBindMethod(this, "SetBoolAndReload", section, "Enabled", !cfg.enabled))
        if cfg.enabled
            indicatorMenu.Check(enabledLabel)

        opacityMenu := Menu()
        currentOpacity := SettingsManager.AlphaToPercent(cfg.opacity)
        for percent in [40, 50, 60, 70, 80, 90, 100] {
            label := percent . "%"
            opacityMenu.Add(label, ObjBindMethod(this, "SetIntAndReload", section, "OpacityPercent", percent))
            if percent == currentOpacity
                opacityMenu.Check(label)
        }
        indicatorMenu.Add("Непрозрачность: " . currentOpacity . "%", opacityMenu)

        positionMenu := Menu()
        positionMenu.Add("↑ Выше на 2 px", ObjBindMethod(this, "AdjustAndReload", section, "OffsetY", cfg.markMargin.y, -2, -200, 200))
        positionMenu.Add("↓ Ниже на 2 px", ObjBindMethod(this, "AdjustAndReload", section, "OffsetY", cfg.markMargin.y, 2, -200, 200))
        positionMenu.Add("← Левее на 2 px", ObjBindMethod(this, "AdjustAndReload", section, "OffsetX", cfg.markMargin.x, -2, -200, 200))
        positionMenu.Add("→ Правее на 2 px", ObjBindMethod(this, "AdjustAndReload", section, "OffsetX", cfg.markMargin.x, 2, -200, 200))
        positionMenu.Add()
        if section == "Mouse"
            positionMenu.Add("Сбросить положение", ObjBindMethod(this, "SetPositionAndReload", section, 18, 12))
        else
            positionMenu.Add("Сбросить положение", ObjBindMethod(this, "SetPositionAndReload", section, 6, -12))
        indicatorMenu.Add("Положение: X " . cfg.markMargin.x . ", Y " . cfg.markMargin.y, positionMenu)

        if includeIdle {
            idleMenu := Menu()
            currentIdle := Round(cfg.mouseIdleHideAfter / 1000)
            options := [0, 1, 2, 3, 5, 10]
            for seconds in options {
                label := seconds == 0 ? "Не скрывать" : seconds . " сек"
                idleMenu.Add(label, ObjBindMethod(this, "SetIntAndReload", section, "HideAfterSeconds", seconds))
                if seconds == currentIdle
                    idleMenu.Check(label)
            }
            indicatorMenu.Add("Скрывать через: " . (currentIdle == 0 ? "никогда" : currentIdle . " сек"), idleMenu)
        }

        return indicatorMenu
    }

    SetBoolAndReload(section, key, value, *) {
        DirCreate(this.settingsDir)
        IniWrite(value ? 1 : 0, this.path, section, key)
        this.ReloadClean()
    }

    SetIntAndReload(section, key, value, *) {
        DirCreate(this.settingsDir)
        IniWrite(value, this.path, section, key)
        this.ReloadClean()
    }

    AdjustAndReload(section, key, currentValue, delta, minValue, maxValue, *) {
        nextValue := Max(minValue, Min(maxValue, currentValue + delta))
        this.SetIntAndReload(section, key, nextValue)
    }

    SetPositionAndReload(section, x, y, *) {
        DirCreate(this.settingsDir)
        IniWrite(x, this.path, section, "OffsetX")
        IniWrite(y, this.path, section, "OffsetY")
        this.ReloadClean()
    }

    ReloadClean(*) {
        try A_IconHidden := true
        Sleep(30)
        Reload()
    }

    ExitClean(*) {
        try A_IconHidden := true
        Sleep(30)
        ExitApp()
    }

    OpenSettingsFolder(*) {
        DirCreate(this.settingsDir)
        Run(this.settingsDir)
    }

    ReadBool(section, key, fallback) {
        raw := IniRead(this.path, section, key, fallback ? "1" : "0")
        return raw == "1" or StrLower(raw) == "true"
    }

    ReadInt(section, key, fallback, minValue, maxValue) {
        raw := IniRead(this.path, section, key, fallback)
        return SettingsManager.ClampInt(raw, minValue, maxValue, fallback)
    }

    static ClampInt(value, minValue, maxValue, fallback) {
        try parsed := Round(value + 0)
        catch
            parsed := fallback
        return Max(minValue, Min(maxValue, parsed))
    }

    static PercentToAlpha(percent) {
        p := SettingsManager.ClampInt(percent, 20, 100, 100)
        return Round(255 * p / 100)
    }

    static AlphaToPercent(alpha) {
        a := SettingsManager.ClampInt(alpha, 0, 255, 255)
        return Round(100 * a / 255)
    }
}
