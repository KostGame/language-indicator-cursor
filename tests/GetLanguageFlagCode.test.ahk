#requires AutoHotkey v2.0

#include ..\lib\detection\GetLanguageFlagCode.ahk
#include TestFramework.ahk

class GetLanguageFlagCodeTests {
    static Run() {
        T.StartSuite("GetLanguageFlagCode")

        T.AssertEqual(GetLanguageFlagCode(0x0419), "ru", "Russian ru-RU maps to ru flag")
        T.AssertEqual(GetLanguageFlagCode(0x0409), "us", "English en-US maps to us flag")
        T.AssertEqual(GetLanguageFlagCode(0x0809), "us", "English en-GB maps to English/us flag")
        T.AssertEqual(GetLanguageFlagCode(0xF0C00419), "ru", "HKL high bits do not affect Russian mapping")
        T.AssertEqual(GetLanguageFlagCode(0xF0C00409), "us", "HKL high bits do not affect English mapping")
        T.AssertEqual(GetLanguageFlagCode(0x0407), "", "Unsupported German layout has no direct flag")
        T.AssertEqual(GetLanguageFlagCode(0), "", "Missing layout has no direct flag")

        T.StartSuite("LanguageFlagResolver")
        LanguageFlagResolver.Reset()
        T.AssertEqual(LanguageFlagResolver.Resolve(0), "", "No marker before first valid layout")
        T.AssertEqual(LanguageFlagResolver.Resolve(0x0409), "us", "Resolver learns English")
        T.AssertEqual(LanguageFlagResolver.Resolve(0), "us", "Transient missing layout keeps last English flag")
        T.AssertEqual(LanguageFlagResolver.Resolve(0x0407), "us", "Transient unsupported helper layout keeps last English flag")
        T.AssertEqual(LanguageFlagResolver.Resolve(0x0419), "ru", "Resolver updates to Russian")
        T.AssertEqual(LanguageFlagResolver.Resolve(0), "ru", "Transient missing layout keeps last Russian flag")
        LanguageFlagResolver.Reset()
    }
}
