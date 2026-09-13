#requires AutoHotkey v2.0

; This file is a library. Direct execution is only used by CI validation.
if (A_ScriptName = "ProcessIsolation.ahk")
    ExitApp()

; Keep caret accessibility work in a different process from mouse/tray logic.
; The worker emits a heartbeat from its own AutoHotkey event loop. If a caret
; accessibility call blocks that loop, the heartbeat stops and the main process
; replaces the worker without disturbing mouse tracking or the tray.
class CaretWorkerHeartbeat {
    __New(generation) {
        this.generation := generation
        this.dir := A_AppData . "\\LanguageIndicatorCursor"
        this.heartbeatPath := this.dir . "\\caret-worker.heartbeat"
        this.controlPath := this.dir . "\\caret-worker.control"
        this.timerFn := ObjBindMethod(this, "Beat")
    }

    Start() {
        DirCreate(this.dir)
        this.Beat()
        RuntimeSetTimer(this.timerFn, 1000)
    }

    Beat(*) {
        try control := Trim(FileRead(this.controlPath))
        catch
            return

        if control != this.generation {
            this.Stop(false)
            ExitApp()
            return
        }

        try {
            file := FileOpen(this.heartbeatPath, "w")
            file.Write(this.generation . "|" . this.Tick())
            file.Close()
        }
    }

    Stop(deleteHeartbeat := true) {
        RuntimeSetTimer(this.timerFn, 0)
        if !deleteHeartbeat
            return

        try {
            raw := Trim(FileRead(this.heartbeatPath))
            parts := StrSplit(raw, "|")
            if parts.Length >= 1 && parts[1] == this.generation
                FileDelete(this.heartbeatPath)
        }
    }

    Tick() {
        return DllCall("GetTickCount64", "UInt64")
    }
}

class CaretWorkerSupervisor {
    __New() {
        this.dir := A_AppData . "\\LanguageIndicatorCursor"
        this.heartbeatPath := this.dir . "\\caret-worker.heartbeat"
        this.controlPath := this.dir . "\\caret-worker.control"
        this.workerPid := 0
        this.generation := ""
        this.workerStartedTick := 0
        this.staleAfterMs := 5000
        this.startGraceMs := 5000
        this.watchdogFn := ObjBindMethod(this, "Watchdog")
        this.running := false
    }

    Start() {
        this.Stop()
        DirCreate(this.dir)
        this.running := true
        this.RestartWorker()
        RuntimeSetTimer(this.watchdogFn, 1000)
    }

    Stop() {
        this.running := false
        RuntimeSetTimer(this.watchdogFn, 0)
        this.WriteControl("STOP")
        this.KillWorker()
        this.DeleteHeartbeat()
    }

    Watchdog(*) {
        if !this.running
            return

        now := this.Tick()

        if !this.workerPid || !ProcessExist(this.workerPid) {
            this.RestartWorker()
            return
        }

        if (now - this.workerStartedTick) < this.startGraceMs
            return

        if !FileExist(this.heartbeatPath) {
            this.RestartWorker()
            return
        }

        try raw := Trim(FileRead(this.heartbeatPath))
        catch {
            this.RestartWorker()
            return
        }

        parts := StrSplit(raw, "|")
        if parts.Length < 2 || parts[1] != this.generation || !IsNumber(parts[2]) {
            this.RestartWorker()
            return
        }

        heartbeatTick := parts[2] + 0
        if (now - heartbeatTick) > this.staleAfterMs
            this.RestartWorker()
    }

    RestartWorker() {
        this.KillWorker()
        this.DeleteHeartbeat()

        this.generation := this.NewGeneration()
        this.WriteControl(this.generation)
        this.workerStartedTick := this.Tick()
        return this.SpawnWorker(this.generation)
    }

    KillWorker() {
        pid := this.workerPid
        this.workerPid := 0
        if !pid
            return

        try {
            if ProcessExist(pid)
                ProcessClose(pid)
        }
    }

    DeleteHeartbeat() {
        try {
            if FileExist(this.heartbeatPath)
                FileDelete(this.heartbeatPath)
        }
    }

    NewGeneration() {
        return A_Pid . "-" . this.Tick() . "-" . Random(1000, 9999)
    }

    WriteControl(value) {
        try {
            DirCreate(this.dir)
            file := FileOpen(this.controlPath, "w")
            file.Write(value)
            file.Close()
        }
    }

    SpawnWorker(generation) {
        cmd := this.BuildWorkerCommand(generation)
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

    BuildWorkerCommand(generation) {
        q := Chr(34)
        if A_IsCompiled {
            workerExe := A_ScriptDir . "\\language-indicator-caret-worker.exe"
            if !FileExist(workerExe)
                return ""
            return q . workerExe . q . " " . generation
        }

        workerScript := A_ScriptDir . "\\caret-worker.ahk"
        if !FileExist(workerScript)
            return ""
        return q . A_AhkPath . q . " " . q . workerScript . q . " " . generation
    }

    Tick() {
        return DllCall("GetTickCount64", "UInt64")
    }
}

RuntimeSetTimer(callback, period) {
    Func("SetTimer").Call(callback, period)
}

GetFirstCommandLineArg(fallback := "") {
    return A_Args.Length >= 1 ? A_Args[1] : fallback
}
