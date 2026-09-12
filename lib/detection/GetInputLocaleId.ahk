; Retrieves the keyboard input locale ID for the active foreground window.
; Transient focus/control races are expected on Windows, so failures return 0
; for the current tick instead of propagating an exception into timer callbacks.
#requires AutoHotkey v2.0
#DllLoad "Imm32"

global imm := DllCall("GetModuleHandle", "Str", "Imm32", "Ptr")
global immGetDefaultIMEWnd := DllCall("GetProcAddress", "Ptr", imm, "AStr", "ImmGetDefaultIMEWnd", "Ptr")

GetInputLocaleId() {
    try {
        foregroundWindow := DllCall("GetForegroundWindow", "Ptr")
        if !foregroundWindow
            return 0

        isConsole := WinActive("ahk_class ConsoleWindowClass")
        isVGUI := WinActive("ahk_class vguiPopupWindow")
        isUWP := WinActive("ahk_class ApplicationFrameWindow")

        if isConsole {
            imeWnd := DllCall(immGetDefaultIMEWnd, "Ptr", foregroundWindow, "Ptr")
            if !imeWnd
                return 0
            foregroundWindow := imeWnd
        } else if isVGUI or isUWP {
            focused := ControlGetFocus("A")
            if !focused
                return 0

            try ctrlId := ControlGetHwnd(focused, "A")
            catch
                return 0

            if !ctrlId
                return 0
            foregroundWindow := ctrlId
        }

        threadId := DllCall("GetWindowThreadProcessId", "Ptr", foregroundWindow, "Ptr", 0, "UInt")
        if !threadId
            return 0

        return DllCall("GetKeyboardLayout", "UInt", threadId, "Ptr")
    } catch {
        return 0
    }
}
