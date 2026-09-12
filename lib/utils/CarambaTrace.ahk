#requires AutoHotkey v2.0

#include ..\detection\GetInputLocaleId.ahk
#include ..\detection\GetLanguageFlagCode.ahk

; Temporary diagnostic tracer for issue #3.
; It does not register keyboard hotkeys. It only polls the physical Shift state
; and records foreground-window/layout transitions around a detected double Shift.
class CarambaTrace {
    static path := A_AppData . "\LanguageIndicatorCursor\caramba-trace.log"
    static lastShiftDown := false
    static lastShiftPressTick := 0
    static traceUntil := 0
    static lastStateKey := ""
    static lastSampleTick := 0

    static Start() {
        try {
            DirCreate(A_AppData . "\LanguageIndicatorCursor")
            if FileExist(this.path)
                FileDelete(this.path)
            this.Log("SESSION", "start version=0.79-kost.6-diag")
            SetTimer(ObjBindMethod(this, "Poll"), 20)
        } catch as err {
            ; Diagnostic code must never break the main indicator.
        }
    }

    static Poll() {
        try {
            now := A_TickCount
            shiftDown := GetKeyState("Shift", "P")

            if (shiftDown and !this.lastShiftDown) {
                delta := this.lastShiftPressTick ? now - this.lastShiftPressTick : -1
                this.Log("SHIFT_DOWN", "delta_ms=" . delta)
                if (delta >= 0 and delta <= 700) {
                    this.traceUntil := now + 5000
                    this.Log("DOUBLE_SHIFT", "trace_window_ms=5000")
                }
                this.lastShiftPressTick := now
            } else if (!shiftDown and this.lastShiftDown) {
                this.Log("SHIFT_UP", "")
            }
            this.lastShiftDown := shiftDown

            snap := this.Snapshot()
            stateKey := snap.hwnd . "|" . snap.process . "|" . snap.class . "|" . snap.threadId . "|" . snap.rawHkl . "|" . snap.resolvedHkl
            if (stateKey != this.lastStateKey) {
                this.lastStateKey := stateKey
                this.LogSnapshot("STATE", snap)
            }

            if (now <= this.traceUntil and now - this.lastSampleTick >= 50) {
                this.lastSampleTick := now
                this.LogSnapshot("TRACE", snap)
            }
        } catch as err {
            try this.Log("TRACE_ERROR", err.Message)
        }
    }

    static Snapshot() {
        hwnd := DllCall("GetForegroundWindow", "Ptr")
        process := ""
        className := ""
        title := ""
        threadId := 0
        rawHkl := 0

        if hwnd {
            try process := WinGetProcessName("ahk_id " . hwnd)
            try className := WinGetClass("ahk_id " . hwnd)
            try title := WinGetTitle("ahk_id " . hwnd)
            threadId := DllCall("GetWindowThreadProcessId", "Ptr", hwnd, "Ptr", 0, "UInt")
            if threadId
                rawHkl := DllCall("GetKeyboardLayout", "UInt", threadId, "Ptr")
        }

        resolvedHkl := GetInputLocaleId()
        rawFlag := GetLanguageFlagCode(rawHkl)
        resolvedFlag := GetLanguageFlagCode(resolvedHkl)

        CoordMode "Mouse", "Screen"
        MouseGetPos(&mouseX, &mouseY)

        return {
            hwnd: hwnd,
            process: process,
            class: className,
            title: title,
            threadId: threadId,
            rawHkl: rawHkl,
            resolvedHkl: resolvedHkl,
            rawFlag: rawFlag,
            resolvedFlag: resolvedFlag,
            mouseX: mouseX,
            mouseY: mouseY
        }
    }

    static LogSnapshot(kind, snap) {
        details := "hwnd=" . snap.hwnd
            . " process=" . this.Safe(snap.process)
            . " class=" . this.Safe(snap.class)
            . " tid=" . snap.threadId
            . " raw_hkl=" . this.Hex(snap.rawHkl)
            . " raw_flag=" . snap.rawFlag
            . " resolved_hkl=" . this.Hex(snap.resolvedHkl)
            . " resolved_flag=" . snap.resolvedFlag
            . " mouse=" . snap.mouseX . "," . snap.mouseY
            . " title=" . this.Safe(snap.title)
        this.Log(kind, details)
    }

    static Log(kind, details) {
        stamp := FormatTime(, "yyyy-MM-dd HH:mm:ss")
        line := stamp . " tick=" . A_TickCount . " " . kind
        if details != ""
            line .= " " . details
        FileAppend(line . "`n", this.path, "UTF-8")
    }

    static Hex(value) {
        return value ? Format("0x{:X}", value) : "0x0"
    }

    static Safe(value) {
        value := StrReplace(value, "`r", " ")
        value := StrReplace(value, "`n", " ")
        value := StrReplace(value, "`t", " ")
        return value
    }
}
