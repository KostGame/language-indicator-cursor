#requires AutoHotkey v2.0

#include core\IndicatorBase.ahk
#include detection\GetCaretRectSafe.ahk
#include detection\GetInputLocaleId.ahk
#include detection\GetLanguageFlagCode.ahk
#include detection\ProcessIntegrity.ahk
#include utils\DebugCaretPosition.ahk
#include utils\UseCachedWhileIdle.ahk

class CaretIndicator extends IndicatorBase {
    static DefaultConfig := {
        debug: false,
        debugCaretPosition: false,
        files: {
            capslockSuffix: "",
            folderExistCheckPeriod: 1000,
            folder: A_ScriptDir . "\img\flags-png\",
            extensions: [".png"]
        },
        markMargin: { x: 6, y: -12 },
        markScale: 2,
        opacity: 179,
        inputCheckPeriod: 20,
        markRepaintPeriod: 16,
        positionCacheTtl: 120,
    }

    __New(cfg?) {
        if !IsSet(cfg)
            cfg := CaretIndicator.DefaultConfig
        super.__New(cfg)
        this.markPainter.scale := cfg.markScale
        this.markPainter.opacity := cfg.opacity
        this.markPainter.windowTitle := "LanguageIndicatorCaretOverlay"
        this.markPainter.hideBeforeMove := true
        this.getCachedPosition := UseCachedWhileIdle(
            () => this.ComputePosition(),
            this.cfg.positionCacheTtl
        )
    }

    Check() {
        localeId := GetInputLocaleId()
        flagCode := LanguageFlagResolver.Resolve(localeId)
        if (flagCode == "") {
            this.DismissCaretOverlay()
            return
        }

        filePath := this.cfg.files.folder . flagCode . ".png"
        if !FileExist(filePath) {
            this.DismissCaretOverlay()
            return
        }

        this.currentMarkObj := { name: flagCode, image: filePath }
        this.PaintMark(this.currentMarkObj)
    }

    GetPosition() {
        return this.getCachedPosition.Call()
    }

    ComputePosition() {
        left := -1, top := -1, bottom := -1, right := -1
        if IsActiveWindowUnsafeForCaretProbe() {
            return {
                left: left,
                top: top,
                right: right,
                bottom: bottom,
                w: 0,
                h: 0,
                detectMethod: "failure (unsafe cross-integrity target)"
            }
        }

        detectMethod := ""
        GetCaretRectSafe(&left, &top, &right, &bottom, &detectMethod)
        w := right - left
        h := bottom - top
        return { left: left, top: top, right: right, bottom: bottom, w: w, h: h, detectMethod: detectMethod }
    }

    PaintMark(markObj) {
        if (!markObj.image or 2 > StrLen(markObj.image)) {
            this.DismissCaretOverlay()
            return
        }

        pos := this.GetPosition()
        if this.cfg.debugCaretPosition
            DebugCaretPosition(pos.left, pos.top, pos.right, pos.bottom, pos.detectMethod)

        if (InStr(pos.detectMethod, "failure") or (pos.w < 1 and pos.h < 1)) {
            this.DismissCaretOverlay()
            return
        }

        this.markPainter.StorePrev()
        this.markPainter.current.name := markObj.name
        this.markPainter.current.image := markObj.image
        this.markPainter.current.x := pos.right
        this.markPainter.current.y := pos.top + Floor(pos.h / 2)
        this.markPainter.Paint()
    }

    DismissCaretOverlay() {
        ; A hidden top-level overlay can occasionally leave a compositor ghost on
        ; Chromium page navigation. Destroy it instead and clear the current mark
        ; so repaint cannot resurrect stale coordinates before a real caret exists.
        this.currentMarkObj := ""
        this.markPainter.RemoveWindow()
        this.markPainter.ClearAll()
    }
}
