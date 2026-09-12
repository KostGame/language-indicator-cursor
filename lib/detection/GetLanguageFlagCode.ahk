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
