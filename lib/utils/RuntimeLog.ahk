#requires AutoHotkey v2.0

global runtimeLogLast := Map()

RuntimeLogError(context, err) {
    global runtimeLogLast

    try {
        message := err is Error ? err.Message : (err . "")
        key := context . "|" . message
        now := A_TickCount

        if runtimeLogLast.Has(key) and (now - runtimeLogLast[key]) < 5000
            return
        runtimeLogLast[key] := now

        dir := A_AppData . "\LanguageIndicatorCursor"
        DirCreate(dir)
        path := dir . "\runtime.log"

        if FileExist(path) and FileGetSize(path) > 65536 {
            oldPath := dir . "\runtime.old.log"
            if FileExist(oldPath)
                FileDelete(oldPath)
            FileMove(path, oldPath, 1)
        }

        stamp := FormatTime(, "yyyy-MM-dd HH:mm:ss")
        detail := err is Error ? err.What . " @ " . err.File . ":" . err.Line : ""
        FileAppend(stamp . " [" . context . "] " . message . (detail != "" ? " | " . detail : "") . "`n", path, "UTF-8")
    }
}
