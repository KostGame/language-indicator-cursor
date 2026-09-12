#requires AutoHotkey v2.0

#include core\IndicatorBase.ahk
#include detection\GetCaretRect.ahk
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
        positionCacheTtl: 1000,
    }

    __New(cfg?) {
        if !IsSet(cfg)
            cfg := CaretIndicator.DefaultConfig
        super.__New(cfg)
        this.markPainter.scale := cfg.markScale
        this.markPainter.opacity := cfg.opacity
        this.getCachedPosition := UseCachedWhileIdle(
            () => this.ComputePosition(),
            this.cfg.positionCacheTtl
        )
    }

    Check() {
        localeId := GetInputLocaleId()
        flagCode := LanguageFlagResolver.Resolve(localeId)

        ; A third-party switcher can briefly expose its own helper window/layout
        ; while rewriting the last word. Keep the last valid RU/EN flag instead
        ; of clearing both overlays during that transient state.
        if (flagCode == "")
            return

        filePath := this.cfg.files.folder . flagCode . ".png"
        if !FileExist(filePath) {
            this.currentMarkObj := ""
            this.markPainter.HideWindow()
            this.markPainter.Clear()
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

        ; Do not run UIA/MSAA/remote-thread caret fallbacks against a window
        ; above our integrity level. A blocked cross-integrity probe can starve
        ; every AHK timer, making both caret and mouse indicators appear dead
        ; until the process is restarted. The mouse indicator stays independent,
        ; and caret probing resumes automatically after focus returns to a normal
        ; window.
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
        GetCaretRect(&left, &top, &right, &bottom, &detectMethod)
        w := right - left
        h := bottom - top
        return { left: left, top: top, right: right, bottom: bottom, w: w, h: h, detectMethod: detectMethod }
    }

    PaintMark(markObj) {
        if (!markObj.image or 2 > StrLen(markObj.image)) {
            this.markPainter.HideWindow()
            this.markPainter.Clear()
            return
        }

        pos := this.GetPosition()
        if this.cfg.debugCaretPosition
            DebugCaretPosition(pos.left, pos.top, pos.right, pos.bottom, pos.detectMethod)

        if (InStr(pos.detectMethod, "failure") or (pos.w < 1 and pos.h < 1)) {
            this.markPainter.HideWindow()
            return
        }

        this.markPainter.StorePrev()
        this.markPainter.current.name := markObj.name
        this.markPainter.current.image := markObj.image
        this.markPainter.current.x := pos.right
        this.markPainter.current.y := pos.top + Floor(pos.h / 2)
        this.markPainter.Paint()
    }
}
