#requires AutoHotkey v2.0

class CaretWorkerHeartbeat {
    __New() {
        this.dir := A_AppData . "\\LanguageIndicatorCursor"
        this.path := this.dir . "\\caret-worker.heartbeat"
        this.timerFn := ObjBindMethod(this, "Beat")
    }

    Start() {
        DirCreate(this.dir)
        this.Beat()
        SetTimer(this.timerFn, 1000)
    }

    Beat(*) {
        try {
            file := FileOpen(this.path, "w")
            file.Write(DllCall("GetTickCount64", "UInt64"))
            file.Close()
        }
    }

    Stop() {
        SetTimer(this.timerFn, 0)
        try FileDelete(this.path)
    }
}

HasCommandLineArg(name) {
    for arg in A_Args {
        if arg == name
            return true
    }
    return false
}
