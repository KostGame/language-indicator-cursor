; Maps a Windows keyboard layout (HKL/LANGID) to the flag asset used by this fork.
#requires AutoHotkey v2.0

GetLanguageFlagCode(inputLocaleId) {
    if !inputLocaleId
        return ""

    ; GetKeyboardLayout() returns an HKL. The low 16 bits contain LANGID,
    ; and PRIMARYLANGID is the low 10 bits of LANGID.
    langId := inputLocaleId & 0xFFFF
    primaryLangId := langId & 0x03FF

    switch primaryLangId {
        case 0x09: ; LANG_ENGLISH
            return "us"
        case 0x19: ; LANG_RUSSIAN
            return "ru"
        default:
            return ""
    }
}

; Some layout switchers briefly move focus to a helper window/thread while they
; rewrite the previous word. During that interval GetKeyboardLayout() can return
; 0 or a layout that is not one of our supported RU/EN layouts. Treat that as a
; transient observation and keep the last known valid RU/EN flag instead of
; making both indicators disappear.
class LanguageFlagResolver {
    static lastValidCode := ""

    static Resolve(inputLocaleId) {
        code := GetLanguageFlagCode(inputLocaleId)
        if (code != "") {
            this.lastValidCode := code
            return code
        }

        return this.lastValidCode
    }

    static Reset() {
        this.lastValidCode := ""
    }
}
