#requires AutoHotkey v2.0

; Keep caret accessibility work in a different process from mouse/tray logic.
; rc4 intentionally keeps supervision simple: start one worker next to the main
; executable and stop it on clean reload/exit. The critical guarantee is that a
; blocked caret probe cannot starve the main process timers.
class CaretWorkerSupervisor {
    __New() {
        this.workerPid := 0
    }

    Start() {
        this.Stop()
        cmd := this.BuildWorkerCommand()
        if cmd == ""
            return false

        try {
            Run(cmd, A_ScriptDir, "Hide", &pid)
            this.workerPid := pid
            return true
        } catch {
            this.workerPid := 0
            return false
        }
    }

    Stop() {
        if !this.workerPid
            return

        try {
            if ProcessExist(this.workerPid)
                ProcessClose(this.workerPid)
        }
        this.workerPid := 0
    }

    BuildWorkerCommand() {
        q := Chr(34)
        if A_IsCompiled {
            workerExe := A_ScriptDir . "\\language-indicator-caret-worker.exe"
            if !FileExist(workerExe)
                return ""
            return q . workerExe . q
        }

        workerScript := A_ScriptDir . "\\caret-worker.ahk"
        if !FileExist(workerScript)
            return ""
        return q . A_AhkPath . q . " " . q . workerScript . q
    }
}
