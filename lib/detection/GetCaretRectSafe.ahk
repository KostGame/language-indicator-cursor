/*
Safe caret-position detector for the reliability fork.

Most applications use cheap Win32/MSAA probes. Windows Terminal is different:
its CASCADIA host does not reliably expose a native Win32 caret, so its caret is
read through UI Automation TextPattern selection. Because caret detection runs
inside the isolated worker process, a stuck accessibility provider can be
recovered by the supervisor watchdog without freezing the mouse indicator.
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

    ; Windows Terminal's CASCADIA host commonly has no native Win32 caret.
    ; TextPattern2/GetCaretRange is not required here: Terminal exposes the
    ; cursor as the TextPattern selection when there is no actual selection.
    if IsWindowsTerminalCaretClass(className)
        and TryWindowsTerminalUiaCaret(&left, &top, &right, &bottom) {
        detectMethod := "isolated:UIA-TextPattern-Selection (className:" . className . ")"
        return true
    }

    ; Browser content controls often do not expose a native Win32 caret, so keep
    ; the MSAA fallback only for well-known browser window classes.
    if IsBrowserCaretClass(className) and TryMsaaCaret(hwnd, &left, &top, &right, &bottom) {
        detectMethod := "safe:MSAA (className:" . className . ")"
        return true
    }

    detectMethod := "failure (safe-only className:" . className . ")"
    return false
}

IsWindowsTerminalCaretClass(className) {
    return className == "CASCADIA_HOSTING_WINDOW_CLASS"
}

IsBrowserCaretClass(className) {
    return InStr(className, "Chrome_WidgetWin_") == 1
        or className == "MozillaWindowClass"
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

TryWindowsTerminalUiaCaret(&left, &top, &right, &bottom) {
    try {
        ; IUIAutomation
        uia := ComObject("{E22AD333-B25F-460C-83D0-0581107395C9}",
            "{30CBE57D-D9D0-452A-AB13-7AC5AC4825EE}")

        ; CreateCacheRequest
        pCache := 0
        ComCall(20, uia, "ptr*", &pCache)
        if !pCache
            return false
        cacheRequest := ComValue(13, pCache, 1)

        ; AddPattern(UIA_TextPatternId = 10014)
        ComCall(4, cacheRequest, "ptr", 10014)

        ; GetFocusedElementBuildCache
        pFocused := 0
        ComCall(12, uia, "ptr", cacheRequest, "ptr*", &pFocused)
        if !pFocused
            return false
        focused := ComValue(13, pFocused, 1)

        iidTextPattern := GuidBuffer("{32EBA289-3583-42C9-9C59-3B6D9A1E9B6A}")

        ; GetCachedPatternAs(UIA_TextPatternId, IID_IUIAutomationTextPattern)
        pPattern := 0
        ComCall(15, focused,
            "int", 10014,
            "ptr", iidTextPattern,
            "ptr*", &pPattern)
        if !pPattern
            return false
        textPattern := ComValue(13, pPattern, 1)

        ; GetSelection. Windows Terminal returns a degenerate range at the
        ; cursor position when there is no real text selection.
        pRanges := 0
        ComCall(5, textPattern, "ptr*", &pRanges)
        if !pRanges
            return false
        ranges := ComValue(13, pRanges, 1)

        len := 0
        ComCall(3, ranges, "int*", &len)
        if len < 1
            return false

        pRange := 0
        ComCall(4, ranges, "int", len - 1, "ptr*", &pRange)
        if !pRange
            return false
        range := ComValue(13, pRange, 1)

        ; Collapse a real selection to its end so the marker tracks the insertion
        ; point rather than the beginning of highlighted text.
        try ComCall(15, range, "int", 0, "ptr", range, "int", 1)

        ; A degenerate range has no bounding rectangle. Expanding to one
        ; character makes Terminal expose usable screen coordinates.
        ComCall(6, range, "int", 0) ; TextUnit_Character
        if TryReadUiaRangeRect(range, false, &left, &top, &right, &bottom)
            return true

        ; At end-of-line/document character expansion can fail. Expand to line
        ; and use its right edge as the insertion point.
        ComCall(6, range, "int", 3) ; TextUnit_Line
        return TryReadUiaRangeRect(range, true, &left, &top, &right, &bottom)
    } catch {
        return false
    }
}

TryReadUiaRangeRect(range, useRightEdge, &left, &top, &right, &bottom) {
    psa := 0
    ComCall(10, range, "ptr*", &psa) ; GetBoundingRectangles
    if !psa
        return false

    rects := ComValue(0x2005, psa, 1) ; VT_ARRAY | VT_R8
    if rects.MaxIndex() < 3
        return false

    x := Round(rects[0])
    y := Round(rects[1])
    w := Round(rects[2])
    h := Round(rects[3])
    if h < 1
        return false

    if useRightEdge
        x += w

    left := x
    top := y
    right := x + 1
    bottom := y + h
    return (left != 0 or top != 0)
}

GuidBuffer(guidText) {
    buf := Buffer(16, 0)
    if DllCall("ole32\\CLSIDFromString", "wstr", guidText, "ptr", buf, "int") != 0
        throw Error("Invalid GUID: " . guidText)
    return buf
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

        pAcc := 0
        hr := DllCall("oleacc\\AccessibleObjectFromWindow"
            , "ptr", hwnd
            , "uint", idObject
            , "ptr", iid
            , "ptr*", &pAcc
            , "int")
        if hr != 0 or !pAcc
            return false

        acc := ComValue(9, pAcc, 1)
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
