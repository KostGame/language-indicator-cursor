; Abstract base class for the fork's mouse/caret indicators.
#requires AutoHotkey v2.0

#include ..\image-utils\ImagePainter.ahk
#include ..\utils\RuntimeLog.ahk

class IndicatorBase {
    static SHUTDOWN_REASONS := "^(?i:Logoff|Shutdown)$"
    static PAINTER_HEALTH_PERIOD := 2000

    __New(cfg) {
        this.cfg := cfg
        this.markPainter := ImagePainter()
        this.markPainter.margin := this.cfg.markMargin
        this.currentMarkObj := ""
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
        throw Error("Check must be implemented by subclass")
    }

    Repaint() {
        if (this.currentMarkObj == "")
            return
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
