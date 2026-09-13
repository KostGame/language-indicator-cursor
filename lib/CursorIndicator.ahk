; Shows the current RU/EN keyboard language as a floating flag near the mouse cursor.
;
; Fork-specific behavior:
; - visible for ordinary mouse pointers, not only IBeam text cursors
; - hides after configurable mouse inactivity and reappears on movement
; - layout changes also wake the mouse marker for one idle-timeout window
; - never replaces the Windows system cursor
; - resolves RU/EN from the actual Windows LANGID, not discovery order
; - survives transient helper-window/layout states from third-party switchers
; - ignores Caps Lock for flag selection
; - destroys stale mouse overlay windows on idle/invalid states to avoid ghosts
; - hides the visible overlay before repositioning it to avoid DWM move trails

#requires AutoHotkey v2.0

#include core\IndicatorBase.ahk
#include detection\GetMousePosPrediction.ahk
#include detection\GetInputLocaleId.ahk
#include detection\GetLanguageFlagCode.ahk

class CursorIndicator extends IndicatorBase {
    static DefaultConfig := {
        debug: false,
        files: {
            capslockSuffix: "",
            folderExistCheckPeriod: 1000,
            folder: A_ScriptDir . "\img\flags-png\",
            extensions: [".png"]
        },
        markMargin: { x: 18, y: 12, useCursorSize: false },
        markScale: 2,
        opacity: 230,
        mousePositionPrediction: 0.5,
        mouseIdleHideAfter: 3000,
        inputCheckPeriod: 20,
        markRepaintPeriod: 6,
    }

    __New(cfg?) {
        if !IsSet(cfg)
            cfg := CursorIndicator.DefaultConfig
        super.__New(cfg)

        this.markPainter.scale := cfg.markScale
        this.markPainter.opacity := cfg.opacity
        this.markPainter.windowTitle := "LanguageIndicatorMouseOverlay"
        this.markPainter.hideBeforeMove := true
        this.lastMouseX := ""
        this.lastMouseY := ""
        this.lastMouseMoveTick := A_TickCount
        this.lastFlagCode := ""
    }

    Check() {
        localeId := GetInputLocaleId()
        flagCode := LanguageFlagResolver.Resolve(localeId)
        if (flagCode == "")
            return

        this.NoteLanguage(flagCode)

        filePath := this.cfg.files.folder . flagCode . ".png"
        if !FileExist(filePath) {
            this.DismissOverlay(true)
            return
        }

        this.currentMarkObj := { name: flagCode, image: filePath }
        this.PaintMark(this.currentMarkObj)
    }

    Repaint() {
        if (this.currentMarkObj == "")
            return
        this.PaintMark(this.currentMarkObj)
    }

    GetPosition() {
        return GetMousePos(this.cfg.mousePositionPrediction)
    }

    NoteLanguage(flagCode, nowTick?) {
        if !IsSet(nowTick)
            nowTick := A_TickCount

        if (flagCode != "" and flagCode != this.lastFlagCode) {
            this.lastFlagCode := flagCode
            this.lastMouseMoveTick := nowTick
            return true
        }
        return false
    }

    IsMouseActive(pos, nowTick?) {
        if !IsSet(nowTick)
            nowTick := A_TickCount

        if (this.lastMouseX == "" or this.lastMouseY == "" or pos.x != this.lastMouseX or pos.y != this.lastMouseY) {
            this.lastMouseX := pos.x
            this.lastMouseY := pos.y
            this.lastMouseMoveTick := nowTick
            return true
        }

        if (this.cfg.mouseIdleHideAfter <= 0)
            return true

        return (nowTick - this.lastMouseMoveTick) < this.cfg.mouseIdleHideAfter
    }

    DismissOverlay(clearMark := false) {
        this.markPainter.RemoveWindow()
        this.markPainter.ClearAll()
        if clearMark
            this.currentMarkObj := ""
    }

    PaintMark(markObj) {
        if (!markObj.image or 10 > StrLen(markObj.image)) {
            this.DismissOverlay(true)
            return
        }

        pos := this.GetPosition()
        if (pos.x == -1 or pos.y == -1) {
            this.DismissOverlay(false)
            return
        }

        if !this.IsMouseActive(pos) {
            this.DismissOverlay(false)
            return
        }

        this.markPainter.StorePrev()
        this.markPainter.current.name := markObj.name
        this.markPainter.current.image := markObj.image
        this.markPainter.current.x := pos.x
        this.markPainter.current.y := pos.y

        this.markPainter.Paint()
    }
}
