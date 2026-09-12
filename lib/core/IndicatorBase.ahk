; Abstract base class for language indicators with common mark painting logic
#requires AutoHotkey v2.0

#include MarkResolver.ahk
#include ..\detection\InputState.ahk
#include ..\image-utils\ImagePainter.ahk
#include ..\image-utils\UseBase64Image.ahk
#include ..\utils\UseCached.ahk
#include ..\utils\RuntimeLog.ahk

class IndicatorBase {
    static SHUTDOWN_REASONS := "^(?i:Logoff|Shutdown)$"
    static PAINTER_HEALTH_PERIOD := 2000

    __New(cfg) {
        this.cfg := cfg
        this.inputState := InputState()
        this.markPainter := ImagePainter()
        this.markPainter.margin := this.cfg.markMargin
        this.currentMarkObj := ""

        this.folderExistsCache := UseCached(
            () => DirExist(this.cfg.files.folder),
            this.cfg.files.folderExistCheckPeriod
        )
    }

    Run() {
        SetTimer(() => this.SafeCheck(), this.cfg.inputCheckPeriod)
        SetTimer(() => this.SafeRepaint(), this.cfg.markRepaintPeriod)
        SetTimer(() => this.SafePainterHealthCheck(), IndicatorBase.PAINTER_HEALTH_PERIOD)
        OnExit((reason, code) => this.OnExit(reason, code))
    }

    SafeCheck() {
        try this.Check()
        catch as err
            RuntimeLogError(Type(this) . ".Check", err)
    }

    SafeRepaint() {
        try this.Repaint()
        catch as err
            RuntimeLogError(Type(this) . ".Repaint", err)
    }

    SafePainterHealthCheck() {
        try this.markPainter.HealthCheck()
        catch as err
            RuntimeLogError(Type(this) . ".PainterHealth", err)
    }

    Check() {
        this.inputState.Update()
        this.FolderExists()
            ? this.UseMarkFile()
            : this.UseMarkEmbedded()
    }

    Repaint() {
        if (this.currentMarkObj == "")
            return
        this.PaintMark(this.currentMarkObj)
    }

    FolderExists() {
        return this.folderExistsCache.Call()
    }

    UseMarkEmbedded() {
        markName := MarkResolver.GetMarkName(this.inputState.locale, this.inputState.capslock)
        if (markName == "") {
            this.currentMarkObj := ""
            this.markPainter.RemoveWindow()
            return
        }
        this.currentMarkObj := UseBase64Image(markName)
        this.PaintMark(this.currentMarkObj)
    }

    UseMarkFile() {
        markName := MarkResolver.GetMarkName(this.inputState.locale, this.inputState.capslock)
        if (markName == "") {
            this.currentMarkObj := ""
            this.markPainter.RemoveWindow()
            return
        }
        markFile := MarkResolver.GetMarkFile(this.cfg.files, this.inputState.locale, this.inputState.capslock)
        this.currentMarkObj := { name: markName, image: markFile }
        this.PaintMark(this.currentMarkObj)
    }

    PaintMark(markObj) {
        throw Error("PaintMark must be implemented by subclass")
    }

    GetPosition() {
        throw Error("GetPosition must be implemented by subclass")
    }

    OnExit(reason, code) {
        if !(reason ~= IndicatorBase.SHUTDOWN_REASONS)
            this.markPainter.RemoveWindow()
    }
}
