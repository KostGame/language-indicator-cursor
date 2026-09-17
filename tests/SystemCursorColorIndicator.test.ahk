#requires AutoHotkey v2.0

#include ..\lib\SystemCursorColorIndicator.ahk
#include TestFramework.ahk

class SystemCursorColorIndicatorTests {
    static Run() {
        this.TestColorMapping()
        this.TestCursorRoleCoverage()
    }

    static TestColorMapping() {
        T.StartSuite("SystemCursorColorIndicator.ColorMapping")

        indicator := SystemCursorColorIndicator(SystemCursorColorIndicator.DefaultConfig)
        T.AssertEqual(indicator.ColorForCode("ru"), 0xE53935, "Russian layout uses red accent")
        T.AssertEqual(indicator.ColorForCode("us"), 0x2F80ED, "English layout uses blue accent")
        T.AssertEqual(indicator.ColorForCode("de"), 0, "Unsupported layout has no system-cursor accent")
    }

    static TestCursorRoleCoverage() {
        T.StartSuite("SystemCursorColorIndicator.CursorRoles")

        roles := SystemCursorColorIndicator.CURSOR_IDS
        T.Assert(this.HasValue(roles, 32512), "Arrow cursor role is covered")
        T.Assert(this.HasValue(roles, 32513), "IBeam cursor role is covered")
        T.Assert(this.HasValue(roles, 32649), "Hand cursor role is covered")
        T.Assert(this.HasValue(roles, 32644), "Horizontal resize cursor role is covered")
        T.Assert(!this.HasValue(roles, 32514), "Animated Wait cursor is intentionally excluded from beta.1")
        T.Assert(!this.HasValue(roles, 32650), "Animated AppStarting cursor is intentionally excluded from beta.1")
    }

    static HasValue(values, expected) {
        for value in values {
            if value == expected
                return true
        }
        return false
    }
}
