#requires AutoHotkey v2.0

CreateLanguageIndicatorDefaultConfig() {
    return {
        caret: {
            enabled: true,
            inputCheckPeriod: 20,
            markRepaintPeriod: 16,
            markMargin: { x: 6, y: -12 },
            markScale: 2,
            opacity: 179
        },
        cursor: {
            enabled: false,
            inputCheckPeriod: 20,
            markRepaintPeriod: 6,
            markMargin: { x: 18, y: 12, useCursorSize: false },
            markScale: 2,
            opacity: 230,
            mouseIdleHideAfter: 3000
        }
    }
}
