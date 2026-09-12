/*
Safe caret-position detector for the reliability fork.

This intentionally avoids every fallback that can wait on another process or
on a potentially unresponsive accessibility provider. The goal is fail-closed
reliability: if a difficult application cannot expose its caret through the
cheap Windows APIs below, hide only the caret flag and keep the indicator
runtime alive.
*/
#requires AutoHotkey v2.0

GetCaretRectSafe(&left?, &top?, &right?, &bottom?, &detectMethod?) {
    left := -1, top := -1, right := -1, bottom := -1
    detectMethod := "failure"

    hwnd := 0
    try hwnd := WinGetID("A")
    catch
        hwnd := 0

    if !hwnd {
        detectMethod := "failure (no active hwnd)"
        return false
    }

    className := "unknown"
    try className := WinGetClass(hwnd)

    if TryGuiCaret(hwnd, &left, &top, &right, &bottom) {
        detectMethod := "safe:GetGUIThreadInfo (className:" . className . ")"
        return true
    }

    ; MSAA is the only cross-window accessibility fallback kept in rc3. We do
    ; not invoke UI Automation or the upstream remote-thread hook here because
    ; either can potentially wait on a provider/target and starve all AHK timers.
    if TryMsaaCaret(hwnd, &left, &top, &right, &bottom) {
        detectMethod := "safe:MSAA (className:" . className . ")"
        return true
    }

    detectMethod := "failure (safe-only className:" . className . ")"
    return false
}

TryGuiCaret(hwnd, &left, &top, &right, &bottom) {
    x64 := A_PtrSize == 8
    info := Buffer(x64 ? 72 : 48, 0)
    NumPut("uint", info.Size, info)

    if !DllCall("GetGUIThreadInfo", "uint", 0, "ptr", info)
        return false

    caretHwnd := NumGet(info, x64 ? 48 : 28, "ptr")
    if !caretHwnd
        return false

    rectOffset := x64 ? 56 : 32
    left := NumGet(info, rectOffset + 0, "int")
    top := NumGet(info, rectOffset + 4, "int")
    right := NumGet(info, rectOffset + 8, "int")
    bottom := NumGet(info, rectOffset + 12, "int")

    w := right - left
    h := bottom - top
    pt := Buffer(8, 0)
    NumPut("int", left, pt, 0)
    NumPut("int", top, pt, 4)
    if !DllCall("ClientToScreen", "ptr", caretHwnd, "ptr", pt)
        return false

    left := NumGet(pt, 0, "int")
    top := NumGet(pt, 4, "int")
    right := left + w
    bottom := top + h
    return (left != 0 or top != 0 or right != 0 or bottom != 0)
}

TryMsaaCaret(hwnd, &left, &top, &right, &bottom) {
    hOleacc := DllCall("LoadLibraryW", "str", "oleacc.dll", "ptr")
    if !hOleacc
        return false

    try {
        idObject := 0xFFFFFFF8 ; OBJID_CARET
        iid := Buffer(16, 0)
        ; IID_IAccessible {618736E0-3C3D-11CF-810C-00AA00389B71}
        NumPut("uint", 0x618736E0, iid, 0)
        NumPut("ushort", 0x3C3D, iid, 4)
        NumPut("ushort", 0x11CF, iid, 6)
        NumPut("uchar", 0x81, iid, 8)
        NumPut("uchar", 0x0C, iid, 9)
        NumPut("uchar", 0x00, iid, 10)
        NumPut("uchar", 0xAA, iid, 11)
        NumPut("uchar", 0x00, iid, 12)
        NumPut("uchar", 0x38, iid, 13)
        NumPut("uchar", 0x9B, iid, 14)
        NumPut("uchar", 0x71, iid, 15)

        acc := ComValue(9, 0)
        hr := DllCall("oleacc\AccessibleObjectFromWindow"
            , "ptr", hwnd
            , "uint", idObject
            , "ptr", iid
            , "ptr*", acc
            , "int")
        if hr != 0 or !acc.Ptr
            return false

        x := Buffer(4), y := Buffer(4), w := Buffer(4), h := Buffer(4)
        try acc.accLocation(
            ComValue(0x4003, x.Ptr, 1),
            ComValue(0x4003, y.Ptr, 1),
            ComValue(0x4003, w.Ptr, 1),
            ComValue(0x4003, h.Ptr, 1),
            0)
        catch
            return false

        X := NumGet(x, 0, "int")
        Y := NumGet(y, 0, "int")
        W := NumGet(w, 0, "int")
        H := NumGet(h, 0, "int")
        if (X | Y) == 0
            return false
        if W < 1
            W := 1
        if H < 1
            H := 1

        left := X, top := Y, right := X + W, bottom := Y + H
        return true
    } finally {
        DllCall("FreeLibrary", "ptr", hOleacc)
    }
}
