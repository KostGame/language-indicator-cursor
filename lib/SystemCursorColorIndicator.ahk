; Recolors the standard Windows cursor set with a thin language-colored outline.
; RU = red accent, EN = blue accent. The underlying cursor shape/hotspot is preserved.
;
; This is intentionally separate from the floating mouse flag. It changes the actual
; Windows system cursor roles so Arrow/Hand/IBeam/resize/etc keep the same language
; cue when the pointer changes shape. Applications that draw their own custom cursor
; can still override the system cursor.
#requires AutoHotkey v2.0

#include detection\GetInputLocaleId.ahk
#include detection\GetLanguageFlagCode.ahk
#include utils\RuntimeLog.ahk

class SystemCursorColorIndicator {
    ; Static cursor roles. WAIT / APPSTARTING are deliberately excluded from beta.1
    ; because recreating them through CreateIconIndirect would freeze animation.
    static CURSOR_IDS := [
        32512, ; OCR_NORMAL / Arrow
        32513, ; OCR_IBEAM
        32515, ; OCR_CROSS
        32516, ; OCR_UP
        32642, ; OCR_SIZENWSE
        32643, ; OCR_SIZENESW
        32644, ; OCR_SIZEWE
        32645, ; OCR_SIZENS
        32646, ; OCR_SIZEALL
        32648, ; OCR_NO
        32649, ; OCR_HAND
        32651, ; OCR_HELP
        32671, ; OCR_PIN
        32672  ; OCR_PERSON
    ]

    static DefaultConfig := {
        enabled: true,
        inputCheckPeriod: 30,
        ruColor: 0xE53935,
        usColor: 0x2F80ED,
        alphaThreshold: 48
    }

    __New(cfg?) {
        this.cfg := IsSet(cfg) ? cfg : SystemCursorColorIndicator.DefaultConfig
        this.originals := Map()
        this.variants := Map("ru", Map(), "us", Map())
        this.lastCode := ""
        this.started := false
        this.timerFn := ObjBindMethod(this, "SafeCheck")
    }

    Run() {
        if this.started
            return

        this.CaptureCursorSet()
        if this.originals.Count == 0
            throw Error("No standard system cursors could be captured")

        this.started := true
        this.SafeCheck()
        SetTimer(this.timerFn, this.cfg.inputCheckPeriod)
    }

    Stop() {
        if !this.started and this.originals.Count == 0
            return

        SetTimer(this.timerFn, 0)
        try this.RestoreOriginals()
        catch as err
            RuntimeLogError("SystemCursorColorIndicator.Restore", err)

        this.DestroyStoredHandles()
        this.lastCode := ""
        this.started := false
    }

    SafeCheck() {
        try this.Check()
        catch as err
            RuntimeLogError("SystemCursorColorIndicator.Check", err)
    }

    Check() {
        code := LanguageFlagResolver.Resolve(GetInputLocaleId())
        if (code == "" or code == this.lastCode)
            return

        if this.ApplyVariant(code)
            this.lastCode := code
    }

    ColorForCode(code) {
        switch code {
            case "ru":
                return this.cfg.ruColor
            case "us":
                return this.cfg.usColor
            default:
                return 0
        }
    }

    CaptureCursorSet() {
        ; Capture before modifying anything so exit can restore exactly what the
        ; current desktop was using, even if SPI_SETCURSORS is unreliable.
        for cursorId in SystemCursorColorIndicator.CURSOR_IDS {
            hShared := DllCall("user32\LoadCursorW", "ptr", 0, "ptr", cursorId, "ptr")
            if !hShared
                continue

            hOriginal := DllCall("user32\CopyIcon", "ptr", hShared, "ptr")
            if !hOriginal
                continue

            this.originals[cursorId] := hOriginal

            hRu := this.CreateAccentedCursor(hShared, this.cfg.ruColor)
            if hRu
                this.variants["ru"][cursorId] := hRu

            hUs := this.CreateAccentedCursor(hShared, this.cfg.usColor)
            if hUs
                this.variants["us"][cursorId] := hUs
        }
    }

    ApplyVariant(code) {
        if !this.variants.Has(code)
            return false

        variantSet := this.variants[code]
        changed := 0

        for cursorId, hSource in variantSet {
            hCopy := DllCall("user32\CopyIcon", "ptr", hSource, "ptr")
            if !hCopy
                continue

            ; SetSystemCursor destroys hCopy on success.
            ok := DllCall("user32\SetSystemCursor", "ptr", hCopy, "uint", cursorId, "int")
            if ok
                changed += 1
            else
                DllCall("user32\DestroyCursor", "ptr", hCopy)
        }

        return changed > 0
    }

    RestoreOriginals() {
        for cursorId, hSource in this.originals {
            hCopy := DllCall("user32\CopyIcon", "ptr", hSource, "ptr")
            if !hCopy
                continue

            ok := DllCall("user32\SetSystemCursor", "ptr", hCopy, "uint", cursorId, "int")
            if !ok
                DllCall("user32\DestroyCursor", "ptr", hCopy)
        }
    }

    DestroyStoredHandles() {
        for _, hCursor in this.originals
            try DllCall("user32\DestroyCursor", "ptr", hCursor)

        for _, cursorSet in this.variants {
            for _, hCursor in cursorSet
                try DllCall("user32\DestroyCursor", "ptr", hCursor)
        }

        this.originals := Map()
        this.variants := Map("ru", Map(), "us", Map())
    }

    CreateAccentedCursor(hCursor, accentRgb) {
        info := this.GetCursorInfo(hCursor)
        if !info.ok
            return 0

        black := this.CreateRenderSurface(info.w, info.h, 0xFF000000)
        white := this.CreateRenderSurface(info.w, info.h, 0xFFFFFFFF)
        output := this.CreateRenderSurface(info.w, info.h, 0x00000000)

        if !black.hbm or !white.hbm or !output.hbm {
            this.DeleteSurface(black)
            this.DeleteSurface(white)
            this.DeleteSurface(output)
            return 0
        }

        try {
            this.DrawCursor(black, hCursor, info.w, info.h)
            this.DrawCursor(white, hCursor, info.w, info.h)

            pixelCount := info.w * info.h
            source := Buffer(pixelCount * 4, 0)

            Loop pixelCount {
                index := A_Index - 1
                offset := index * 4
                pxBlack := NumGet(black.bits + offset, "UInt")
                pxWhite := NumGet(white.bits + offset, "UInt")

                bb := pxBlack & 0xFF
                gb := (pxBlack >> 8) & 0xFF
                rb := (pxBlack >> 16) & 0xFF
                bw := pxWhite & 0xFF
                gw := (pxWhite >> 8) & 0xFF
                rw := (pxWhite >> 16) & 0xFF

                delta := Round(((rw - rb) + (gw - gb) + (bw - bb)) / 3)
                alpha := 255 - delta
                alpha := Max(0, Min(255, alpha))

                if alpha < 4 {
                    NumPut("UInt", 0, source, offset)
                    continue
                }

                r := Max(0, Min(255, Round(rb * 255 / alpha)))
                g := Max(0, Min(255, Round(gb * 255 / alpha)))
                b := Max(0, Min(255, Round(bb * 255 / alpha)))
                NumPut("UInt", (alpha << 24) | (r << 16) | (g << 8) | b, source, offset)
            }

            accentR := (accentRgb >> 16) & 0xFF
            accentG := (accentRgb >> 8) & 0xFF
            accentB := accentRgb & 0xFF
            accentPixel := 0xFF000000 | (accentR << 16) | (accentG << 8) | accentB
            radius := Max(1, Round(Min(info.w, info.h) / 32))

            Loop info.h {
                y := A_Index - 1
                Loop info.w {
                    x := A_Index - 1
                    index := y * info.w + x
                    offset := index * 4
                    srcPixel := NumGet(source, offset, "UInt")
                    alpha := (srcPixel >> 24) & 0xFF

                    if alpha >= this.cfg.alphaThreshold {
                        NumPut("UInt", srcPixel, output.bits + offset)
                        continue
                    }

                    if this.HasOpaqueNeighbor(source, info.w, info.h, x, y, radius, this.cfg.alphaThreshold)
                        NumPut("UInt", accentPixel, output.bits + offset)
                    else
                        NumPut("UInt", 0, output.bits + offset)
                }
            }

            hMask := DllCall("gdi32\CreateBitmap", "int", info.w, "int", info.h, "uint", 1, "uint", 1, "ptr", 0, "ptr")
            if !hMask
                return 0

            maskDc := DllCall("gdi32\CreateCompatibleDC", "ptr", 0, "ptr")
            oldMask := DllCall("gdi32\SelectObject", "ptr", maskDc, "ptr", hMask, "ptr")
            DllCall("gdi32\PatBlt", "ptr", maskDc, "int", 0, "int", 0, "int", info.w, "int", info.h, "uint", 0x00000042)
            DllCall("gdi32\SelectObject", "ptr", maskDc, "ptr", oldMask, "ptr")
            DllCall("gdi32\DeleteDC", "ptr", maskDc)

            ii := Buffer(8 + 3 * A_PtrSize, 0)
            NumPut("UInt", 0, ii, 0)
            NumPut("UInt", info.xHotspot, ii, 4)
            NumPut("UInt", info.yHotspot, ii, 8)
            NumPut("Ptr", hMask, ii, 8 + A_PtrSize)
            NumPut("Ptr", output.hbm, ii, 8 + 2 * A_PtrSize)

            hNew := DllCall("user32\CreateIconIndirect", "ptr", ii, "ptr")
            DllCall("gdi32\DeleteObject", "ptr", hMask)
            return hNew
        } finally {
            this.DeleteSurface(black)
            this.DeleteSurface(white)
            this.DeleteSurface(output)
        }
    }

    HasOpaqueNeighbor(source, w, h, x, y, radius, threshold) {
        minY := Max(0, y - radius)
        maxY := Min(h - 1, y + radius)
        minX := Max(0, x - radius)
        maxX := Min(w - 1, x + radius)

        yy := minY
        while yy <= maxY {
            xx := minX
            while xx <= maxX {
                if (xx != x or yy != y) {
                    pixel := NumGet(source, (yy * w + xx) * 4, "UInt")
                    if (((pixel >> 24) & 0xFF) >= threshold)
                        return true
                }
                xx += 1
            }
            yy += 1
        }

        return false
    }

    GetCursorInfo(hCursor) {
        ii := Buffer(8 + 3 * A_PtrSize, 0)
        if !DllCall("user32\GetIconInfo", "ptr", hCursor, "ptr", ii, "int")
            return { ok: false }

        hMask := NumGet(ii, 8 + A_PtrSize, "Ptr")
        hColor := NumGet(ii, 8 + 2 * A_PtrSize, "Ptr")
        xHotspot := NumGet(ii, 4, "UInt")
        yHotspot := NumGet(ii, 8, "UInt")

        hForSize := hColor ? hColor : hMask
        bitmap := Buffer(A_PtrSize == 8 ? 32 : 24, 0)
        got := hForSize ? DllCall("gdi32\GetObjectW", "ptr", hForSize, "int", bitmap.Size, "ptr", bitmap, "int") : 0
        w := got ? Abs(NumGet(bitmap, 4, "Int")) : 0
        h := got ? Abs(NumGet(bitmap, 8, "Int")) : 0
        if !hColor and h
            h := Floor(h / 2)

        if hMask
            DllCall("gdi32\DeleteObject", "ptr", hMask)
        if hColor
            DllCall("gdi32\DeleteObject", "ptr", hColor)

        return {
            ok: w > 0 and h > 0,
            w: w,
            h: h,
            xHotspot: xHotspot,
            yHotspot: yHotspot
        }
    }

    CreateRenderSurface(w, h, fillArgb) {
        bmi := Buffer(40, 0)
        NumPut("UInt", 40, bmi, 0)
        NumPut("Int", w, bmi, 4)
        NumPut("Int", -h, bmi, 8)
        NumPut("UShort", 1, bmi, 12)
        NumPut("UShort", 32, bmi, 14)
        NumPut("UInt", 0, bmi, 16)

        bits := 0
        hbm := DllCall("gdi32\CreateDIBSection", "ptr", 0, "ptr", bmi, "uint", 0, "ptr*", &bits, "ptr", 0, "uint", 0, "ptr")
        if !hbm
            return { hbm: 0, bits: 0, hdc: 0, old: 0 }

        hdc := DllCall("gdi32\CreateCompatibleDC", "ptr", 0, "ptr")
        old := DllCall("gdi32\SelectObject", "ptr", hdc, "ptr", hbm, "ptr")

        Loop w * h
            NumPut("UInt", fillArgb, bits + (A_Index - 1) * 4)

        return { hbm: hbm, bits: bits, hdc: hdc, old: old }
    }

    DrawCursor(surface, hCursor, w, h) {
        DllCall(
            "user32\DrawIconEx",
            "ptr", surface.hdc,
            "int", 0,
            "int", 0,
            "ptr", hCursor,
            "int", w,
            "int", h,
            "uint", 0,
            "ptr", 0,
            "uint", 0x0003,
            "int"
        )
    }

    DeleteSurface(surface) {
        if !IsObject(surface)
            return
        if surface.hdc {
            if surface.old
                DllCall("gdi32\SelectObject", "ptr", surface.hdc, "ptr", surface.old, "ptr")
            DllCall("gdi32\DeleteDC", "ptr", surface.hdc)
        }
        if surface.hbm
            DllCall("gdi32\DeleteObject", "ptr", surface.hbm)
    }
}
