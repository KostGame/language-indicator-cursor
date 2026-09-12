#requires AutoHotkey v2.0

#include core\IndicatorBase.ahk
#include detection\GetCaretRect.ahk
#include detection\GetInputLocaleId.ahk
#include detection\GetLanguageFlagCode.ahk
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
        markMargin: { x: 6, y: 0 },
        markScale: 2,
        inputCheckPeriod: 50,
        markRepaintPeriod: 16,
        positionCacheTtl: 1000,
    }

    __New(cfg?) {
        if !IsSet(cfg)
            cfg := CaretIndicator.DefaultConfig
        super.__New(cfg)
        this.markPainter.scale := cfg.markScale
        this.getCachedPosition := UseCachedWhileIdle(
            () => this.ComputePosition(),
            this.cfg.positionCacheTtl
        )
    }

    Check() {
        flagCode := GetLanguageFlagCode(GetInputLocaleId())
        if (flagCode == "") {
            this.currentMarkObj := ""
            this.markPainter.HideWindow()
            this.markPainter.Clear()
            return
        }

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
