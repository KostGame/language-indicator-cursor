#requires AutoHotkey v2.0
#include ..\lib\detection\ProcessIntegrity.ahk

class ProcessIntegrityTests {
    static Run() {
        T.StartSuite("ProcessIntegrity")

        currentPid := DllCall("GetCurrentProcessId", "uint")
        rid := GetProcessIntegrityRid(currentPid)
        T.Assert(rid > 0, "Current process integrity RID is readable")

        T.AssertFalse(
            IsWindowUnsafeForCaretProbe(A_ScriptHwnd),
            "The script's own window is safe for caret probing"
        )
    }
}
