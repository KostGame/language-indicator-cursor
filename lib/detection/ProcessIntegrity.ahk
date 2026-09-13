#requires AutoHotkey v2.0

; Returns true when the active foreground window belongs to a process that is
; more privileged than this indicator, or when the target process integrity
; cannot be queried safely. In either case, deep caret probing should be
; skipped so a cross-integrity accessibility call cannot stall the whole app.
IsActiveWindowUnsafeForCaretProbe() {
    hwnd := 0
    try hwnd := WinGetID("A")
    catch
        return false

    return IsWindowUnsafeForCaretProbe(hwnd)
}

IsWindowUnsafeForCaretProbe(hwnd) {
    if !hwnd
        return false

    if !DllCall("GetWindowThreadProcessId", "ptr", hwnd, "uint*", &pid := 0, "uint") or !pid
        return true

    static currentIntegrityRid := 0
    if !currentIntegrityRid
        currentIntegrityRid := GetProcessIntegrityRid(DllCall("GetCurrentProcessId", "uint"))

    ; If we cannot establish our own integrity level, keep legacy behavior.
    if currentIntegrityRid <= 0
        return false

    targetIntegrityRid := GetProcessIntegrityRid(pid)

    ; Fail closed for an inaccessible foreground process. Losing the caret flag
    ; for that window is much safer than letting one blocked probe freeze both
    ; indicators until restart.
    if targetIntegrityRid <= 0
        return true

    return targetIntegrityRid > currentIntegrityRid
}

GetProcessIntegrityRid(pid) {
    static PROCESS_QUERY_LIMITED_INFORMATION := 0x1000
    static TOKEN_QUERY := 0x0008
    static TokenIntegrityLevel := 25

    hProcess := DllCall("OpenProcess", "uint", PROCESS_QUERY_LIMITED_INFORMATION, "int", false, "uint", pid, "ptr")
    if !hProcess
        return 0

    try {
        if !DllCall("advapi32\OpenProcessToken", "ptr", hProcess, "uint", TOKEN_QUERY, "ptr*", &hToken := 0)
            return 0

        try {
            needed := 0
            DllCall("advapi32\GetTokenInformation", "ptr", hToken, "int", TokenIntegrityLevel, "ptr", 0, "uint", 0, "uint*", &needed)
            if needed <= 0
                return 0

            info := Buffer(needed, 0)
            if !DllCall("advapi32\GetTokenInformation", "ptr", hToken, "int", TokenIntegrityLevel, "ptr", info, "uint", info.Size, "uint*", &needed)
                return 0

            sid := NumGet(info, 0, "ptr")
            if !sid
                return 0

            countPtr := DllCall("advapi32\GetSidSubAuthorityCount", "ptr", sid, "ptr")
            if !countPtr
                return 0

            count := NumGet(countPtr, 0, "uchar")
            if count < 1
                return 0

            ridPtr := DllCall("advapi32\GetSidSubAuthority", "ptr", sid, "uint", count - 1, "ptr")
            if !ridPtr
                return 0

            return NumGet(ridPtr, 0, "uint")
        } finally {
            DllCall("CloseHandle", "ptr", hToken)
        }
    } finally {
        DllCall("CloseHandle", "ptr", hProcess)
    }
}
