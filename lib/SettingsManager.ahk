#requires AutoHotkey v2.0

; Persistent per-user settings and a small tray-accessible GUI.
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

        return cfg
    }

    Show(cfg) {
        gui := Gui("+OwnDialogs", "Language Indicator Cursor - Настройки")
        gui.SetFont("s10", "Segoe UI")

        gui.AddText("xm ym w390", "Индикатор у мыши")
        mouseEnabled := gui.AddCheckBox("xm y+8", "Показывать у мыши")
        mouseEnabled.Value := cfg.cursor.enabled ? 1 : 0
        gui.AddText("xm y+10 w155", "Прозрачность, %")
        mouseOpacity := gui.AddEdit("x+8 yp-3 w70", SettingsManager.AlphaToPercent(cfg.cursor.opacity))
        gui.AddText("xm y+10 w155", "Смещение X, px")
        mouseX := gui.AddEdit("x+8 yp-3 w70", cfg.cursor.markMargin.x)
        gui.AddText("xm y+10 w155", "Смещение Y, px")
        mouseY := gui.AddEdit("x+8 yp-3 w70", cfg.cursor.markMargin.y)
        gui.AddText("xm y+10 w155", "Скрывать через, сек")
        mouseIdle := gui.AddEdit("x+8 yp-3 w70", Round(cfg.cursor.mouseIdleHideAfter / 1000))
        gui.AddText("x+8 yp+3 c777777", "0 = не скрывать")

        gui.AddText("xm y+22 w390", "Индикатор у текстовой каретки")
        caretEnabled := gui.AddCheckBox("xm y+8", "Показывать в поле ввода")
        caretEnabled.Value := cfg.caret.enabled ? 1 : 0
        gui.AddText("xm y+10 w155", "Прозрачность, %")
        caretOpacity := gui.AddEdit("x+8 yp-3 w70", SettingsManager.AlphaToPercent(cfg.caret.opacity))
        gui.AddText("xm y+10 w155", "Смещение X, px")
        caretX := gui.AddEdit("x+8 yp-3 w70", cfg.caret.markMargin.x)
        gui.AddText("xm y+10 w155", "Смещение Y, px")
        caretY := gui.AddEdit("x+8 yp-3 w70", cfg.caret.markMargin.y)

        gui.AddText("xm y+18 w390 c777777", "Отрицательное Y поднимает флаг выше. Настройки применятся после автоматического перезапуска.")

        saveButton := gui.AddButton("xm y+18 w120 Default", "Сохранить")
        cancelButton := gui.AddButton("x+10 w120", "Отмена")

        saveButton.OnEvent("Click", (*) => this.SaveAndReload(
            mouseEnabled.Value,
            mouseOpacity.Value,
            mouseX.Value,
            mouseY.Value,
            mouseIdle.Value,
            caretEnabled.Value,
            caretOpacity.Value,
            caretX.Value,
            caretY.Value
        ))
        cancelButton.OnEvent("Click", (*) => gui.Destroy())
        gui.OnEvent("Escape", (*) => gui.Destroy())
        gui.Show("AutoSize Center")
    }

    SaveAndReload(mouseEnabled, mouseOpacity, mouseX, mouseY, mouseIdle, caretEnabled, caretOpacity, caretX, caretY) {
        DirCreate(this.settingsDir)

        IniWrite(mouseEnabled ? 1 : 0, this.path, "Mouse", "Enabled")
        IniWrite(SettingsManager.ClampInt(mouseOpacity, 20, 100, 90), this.path, "Mouse", "OpacityPercent")
        IniWrite(SettingsManager.ClampInt(mouseX, -200, 200, 18), this.path, "Mouse", "OffsetX")
        IniWrite(SettingsManager.ClampInt(mouseY, -200, 200, 12), this.path, "Mouse", "OffsetY")
        IniWrite(SettingsManager.ClampInt(mouseIdle, 0, 3600, 3), this.path, "Mouse", "HideAfterSeconds")

        IniWrite(caretEnabled ? 1 : 0, this.path, "Caret", "Enabled")
        IniWrite(SettingsManager.ClampInt(caretOpacity, 20, 100, 70), this.path, "Caret", "OpacityPercent")
        IniWrite(SettingsManager.ClampInt(caretX, -200, 200, 6), this.path, "Caret", "OffsetX")
        IniWrite(SettingsManager.ClampInt(caretY, -200, 200, -12), this.path, "Caret", "OffsetY")

        Reload()
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
