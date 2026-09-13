#requires AutoHotkey v2.0

; Compatibility shim retained because the current Windows CI validates this
; historical module path directly. The active rc4 runtime implementation lives
; in CaretWorkerRuntime.ahk and is validated through both real entry points.
class ProcessIsolationCompatibilityShim {
}
