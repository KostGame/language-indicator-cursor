#requires AutoHotkey v2.0

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
        SetTimer(this.timerFn, 1000)
    }

    Beat(*) {
        try {
            control := Trim(FileRead(this.controlPath))
            if control != this.generation {
                this.Stop(false)
                ExitApp()
                return
            }
        } catch {
            return
        }

        try {
            file := FileOpen(this.heartbeatPath, "w")
            file.Write(this.generation . "|" . DllCall("GetTickCount64", "UInt64"))
            file.Close()
        }
    }

    Stop(deleteHeartbeat := true) {
        SetTimer(this.timerFn, 0)
        if deleteHeartbeat {
            try {
                raw := Trim(FileRead(this.heartbeatPath))
                parts := StrSplit(raw, "|")
                if parts.Length >= 1 and parts[1] == this.generation
                    FileDelete(this.heartbeatPath)
            }
        }
    }
}

class CaretWorkerSupervisor {
    __New() {
        this.dir := A_AppData . "\\LanguageIndicatorCursor"
        this.heartbeatPath := this.dir . "\\caret-worker.heartbeat"
        this.controlPath := this.dir . "\\caret-worker.control"
        this.generation := ""
        this.workerStartedTick := 0
        this.staleAfterMs := 5000
        this.startGraceMs := 5000
        this.watchdogFn := ObjBindMethod(this, "Watchdog")
        this.running := false
    }

    Start() {
        DirCreate(this.dir)
        this.running := true
        this.RestartWorker()
        SetTimer(this.watchdogFn, 1000)
    }

    Stop() {
        this.running := false
        SetTimer(this.watchdogFn, 0)
        this.WriteControl("STOP")
    }

    Watchdog(*) {
        if !this.running
            return

        now := DllCall("GetTickCount64", "UInt64")
        if (now - this.workerStartedTick) < this.startGraceMs
            return

        if !FileExist(this.heartbeatPath) {
            this.RestartWorker()
            return
        }

        try raw := Trim(FileRead(this.heartbeatPath))
        catch {
            return
        }

        parts := StrSplit(raw, "|")
        if parts.Length < 2 or parts[1] != this.generation or !IsNumber(parts[2]) {
            this.RestartWorker()
            return
        }

        heartbeatTick := parts[2] + 0
        if (now - heartbeatTick) > this.staleAfterMs
            this.RestartWorker()
    }

    RestartWorker() {
        this.generation := this.NewGeneration()
        this.WriteControl(this.generation)
        this.workerStartedTick := DllCall("GetTickCount64", "UInt64")
        this.SpawnWorker(this.generation)
    }

    NewGeneration() {
        return A_Pid . "-" . DllCall("GetTickCount64", "UInt64") . "-" . Random(1000, 9999)
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
        try {
            cmd := this.BuildWorkerCommand(generation)
            if cmd != ""
                Run(cmd, A_ScriptDir, "Hide")
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
}

GetFirstCommandLineArg(fallback := "") {
    return A_Args.Length >= 1 ? A_Args[1] : fallback
}
