/*
Safe caret-position detector for the reliability fork.

The detector deliberately avoids the upstream remote-thread hook fallback.
Modern text hosts such as Chromium/Electron and Windows Terminal are handled
through UI Automation inside the isolated caret worker. TextPattern2 is
preferred because GetCaretRange also reports whether the caret is actually
active, which lets us remove stale overlays when focus leaves a text field.
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

    ; Prefer UIA for modern hosts. Their native Win32/MSAA caret can be absent or
    ; stale even while the actual edit control lives deeper in the accessibility
    ; tree. TextPattern2 gives us an authoritative isActive signal when present.
    if IsModernTextHostClass(className) {
        authoritativeInactive := false
        if TryUiaFocusedCaret(&left, &top, &right, &bottom, &authoritativeInactive) {
            detectMethod := "isolated:UIA-focused-caret (className:" . className . ")"
            return true
        }
        if authoritativeInactive {
            detectMethod := "failure (UIA caret inactive className:" . className . ")"
            return false
        }
    }

    if TryGuiCaret(hwnd, &left, &top, &right, &bottom) {
        detectMethod := "safe:GetGUIThreadInfo (className:" . className . ")"
        return true
    }

    ; Keep MSAA as a final lightweight compatibility fallback for browser hosts.
    if IsBrowserCaretClass(className) and TryMsaaCaret(hwnd, &left, &top, &right, &bottom) {
        detectMethod := "safe:MSAA (className:" . className . ")"
        return true
    }

    detectMethod := "failure (safe-only className:" . className . ")"
    return false
}

IsModernTextHostClass(className) {
    return IsWindowsTerminalCaretClass(className) or IsBrowserCaretClass(className)
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

TryUiaFocusedCaret(&left, &top, &right, &bottom, &authoritativeInactive) {
    authoritativeInactive := false

    try {
        uia := ComObject("{E22AD333-B25F-460C-83D0-0581107395C9}",
            "{30CBE57D-D9D0-452A-AB13-7AC5AC4825EE}")

        pCache := 0
        ComCall(20, uia, "ptr*", &pCache) ; IUIAutomation::CreateCacheRequest
        if !pCache
            return false
        cacheRequest := ComValue(13, pCache, 1)

        ComCall(4, cacheRequest, "ptr", 10014) ; UIA_TextPatternId
        ComCall(4, cacheRequest, "ptr", 10024) ; UIA_TextPattern2Id

        pFocused := 0
        ComCall(12, uia, "ptr", cacheRequest, "ptr*", &pFocused) ; GetFocusedElementBuildCache
        if !pFocused
            return false
        focused := ComValue(13, pFocused, 1)

        ; Prefer TextPattern2. GetCaretRange returns both the caret range and an
        ; isActive flag. FALSE is authoritative: the text provider may remember
        ; an old caret, but it no longer owns keyboard focus, so hide the flag.
        iidTextPattern2 := GuidBuffer("{506A921A-FCC9-409F-B23B-37EB74106872}")
        pPattern2 := 0
        ComCall(15, focused,
            "int", 10024,
            "ptr", iidTextPattern2,
            "ptr*", &pPattern2)

        if pPattern2 {
            textPattern2 := ComValue(13, pPattern2, 1)
            isActive := 0
            pRange := 0
            hr := ComCall(10, textPattern2,
                "int*", &isActive,
                "ptr*", &pRange,
                "int")

            if hr == 0 {
                if !isActive {
                    authoritativeInactive := true
                    return false
                }

                if pRange {
                    range := ComValue(13, pRange, 1)
                    if TryResolveUiaCaretRange(range, &left, &top, &right, &bottom)
                        return true
                }
            }
        }

        ; Older providers may expose only TextPattern. Because we obtained the
        ; element through GetFocusedElementBuildCache, a valid selection range is
        ; still a useful insertion-point fallback for Chromium/Electron/Terminal.
        iidTextPattern := GuidBuffer("{32EBA289-3583-42C9-9C59-3B6D9A1E9B6A}")
        pPattern := 0
        ComCall(15, focused,
            "int", 10014,
            "ptr", iidTextPattern,
            "ptr*", &pPattern)
        if !pPattern
            return false
        textPattern := ComValue(13, pPattern, 1)

        pRanges := 0
        ComCall(5, textPattern, "ptr*", &pRanges) ; GetSelection
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

        ; Collapse a real selection to its end. Degenerate selections are left
        ; at the insertion point.
        try ComCall(15, range, "int", 0, "ptr", range, "int", 1)
        return TryResolveUiaCaretRange(range, &left, &top, &right, &bottom)
    } catch {
        return false
    }
}

TryResolveUiaCaretRange(range, &left, &top, &right, &bottom) {
    ; Some providers return a visible rectangle even for a degenerate caret.
    if TryReadUiaRangeRect(range, false, &left, &top, &right, &bottom)
        return true

    ; Otherwise expand the zero-length range to one character and use its left
    ; edge as the insertion point.
    try ComCall(6, range, "int", 0) ; TextUnit_Character
    if TryReadUiaRangeRect(range, false, &left, &top, &right, &bottom)
        return true

    ; End-of-line/document can reject character expansion. Expand to line and
    ; use the right edge instead.
    try ComCall(6, range, "int", 3) ; TextUnit_Line
    return TryReadUiaRangeRect(range, true, &left, &top, &right, &bottom)
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
    if DllCall("ole32\CLSIDFromString", "wstr", guidText, "ptr", buf, "int") != 0
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
        hr := DllCall("oleacc\AccessibleObjectFromWindow"
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
