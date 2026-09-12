/*
Safe caret-position detector for the reliability fork.

This intentionally uses only in-process Windows accessibility/query APIs and
never injects a remote thread into the foreground application. The upstream
GetCaretRect fallback can execute code inside the target process and then wait
for the remote thread. That is useful for a few difficult apps, but a stalled
probe can freeze all AutoHotkey timers in this single-process indicator.
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

    ; MSAA is cheap and works well for classic controls and Chromium-based apps.
    if TryMsaaCaret(hwnd, &left, &top, &right, &bottom) {
        detectMethod := "safe:MSAA (className:" . className . ")"
        return true
    }

    ; UI Automation covers modern controls/Terminal without remote injection.
    if TryUiaCaret(&left, &top, &right, &bottom) {
        detectMethod := "safe:UIA (className:" . className . ")"
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

TryUiaCaret(&left, &top, &right, &bottom) {
    try {
        uia := ComObject("{E22AD333-B25F-460C-83D0-0581107395C9}", "{30CBE57D-D9D0-452A-AB13-7AC5AC4825EE}")
        ComCall(20, uia, "ptr*", cacheRequest := ComValue(13, 0))
        if !cacheRequest.Ptr
            return false

        ComCall(4, cacheRequest, "ptr", 10014) ; UIA_TextPatternId
        ComCall(4, cacheRequest, "ptr", 10024) ; UIA_TextPattern2Id
        ComCall(12, uia, "ptr", cacheRequest, "ptr*", focused := ComValue(13, 0))
        if !focused.Ptr
            return false

        range := ComValue(13, 0)
        iidText2 := GuidBuffer("{506A921A-FCC9-409F-B23B-37EB74106872}")
        ComCall(15, focused, "int", 10024, "ptr", iidText2, "ptr*", text2 := ComValue(13, 0))
        if text2.Ptr {
            ComCall(10, text2, "int*", &isActive := 0, "ptr*", range)
        }

        if !range.Ptr {
            iidText := GuidBuffer("{32EBA289-3583-42C9-9C59-3B6D9A1E9B6A}")
            ComCall(15, focused, "int", 10014, "ptr", iidText, "ptr*", text := ComValue(13, 0))
            if !text.Ptr
                return false
            ComCall(5, text, "ptr*", ranges := ComValue(13, 0))
            if !ranges.Ptr
                return false
            ComCall(3, ranges, "int*", &len := 0)
            if len < 1
                return false
            ComCall(4, ranges, "int", len - 1, "ptr*", range)
            if !range.Ptr
                return false
            ComCall(15, range, "int", 0, "ptr", range, "int", 1)
        }

        psa := 0
        ComCall(6, range, "int", 0) ; TextUnit_Character
        ComCall(10, range, "ptr*", &psa)
        if !psa
            return false

        rects := ComValue(0x2005, psa, 1) ; SafeArray<double>
        if rects.MaxIndex() < 3
            return false

        left := Round(rects[0])
        top := Round(rects[1])
        width := Round(rects[2])
        height := Round(rects[3])
        if width < 1
            width := 1
        if height < 1
            height := 1
        right := left + width
        bottom := top + height
        return true
    } catch {
        return false
    }
}

GuidBuffer(text) {
    buf := Buffer(16, 0)
    DllCall("ole32\CLSIDFromString", "str", text, "ptr", buf, "hresult")
    return buf
}
