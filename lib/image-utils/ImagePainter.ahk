; Displays images in transparent always-on-top windows for visual indicators
#requires AutoHotkey v2.0
#include ImagePut.ahk

class ImagePainter {
    __New() {
        this.bgColor := "ffffff"
        this.window := ""
        this.imageHwnd := 0
        this.windowVisible := false
        this.windowCreatedTick := 0
        ; Even if both HWNDs still exist, periodically rebuild the tiny overlay.
        ; This recovers from rare compositor/ImageShow states where the parent
        ; stays visible but the flag content turns blank/white after long use.
        this.healthRefreshPeriod := 15000
        this.margin := { x: 0, y: 0 }
        this.scale := 1
        this.opacity := 255
        this.current := { image: "", name: "", x: "", y: "", w: 0, h: 0 }
        this.prev := { image: "", name: "", x: "", y: "", w: 0, h: 0 }
    }

    Clear() {
        this.current := { image: "", name: "", x: "", y: "", w: 0, h: 0 }
    }

    ClearAll() {
        this.Clear()
        this.prev := { image: "", name: "", x: "", y: "", w: 0, h: 0 }
    }

    StorePrev() {
        this.prev := this.current.Clone()
    }

    Paint() {
        if !this._hasValidState()
            return

        this._dropStaleWindow()
        imageChanged := this._hasImageChanged()

        ; A surviving parent GUI is not enough to prove that the actual
        ; ImageShow child is healthy. Recreate immediately when the image child
        ; disappeared, and periodically refresh a long-lived overlay so a blank
        ; compositor surface cannot remain stuck forever.
        if (this.window != "" and (imageChanged or this._shouldHealthRefresh()))
            this.RemoveWindow()

        if this._canSkipRepaint(imageChanged)
            return

        if !this._loadDimensions(imageChanged)
            return

        if !this._ensureWindow()
            return

        this._showAtPosition()
    }

    RemoveWindow() {
        if this.window != ""
            try this.window.Destroy()
        this.window := ""
        this.imageHwnd := 0
        this.windowVisible := false
        this.windowCreatedTick := 0
    }

    HideWindow() {
        if this.window != "" {
            if !this._windowExists() {
                this._forgetWindow()
                return
            }
            try this.window.Hide()
            catch {
                this._forgetWindow()
                return
            }
            this.windowVisible := false
        }
    }

    ; Private methods

    _windowExists() {
        if this.window == ""
            return false
        try {
            hwnd := this.window.Hwnd
            return hwnd and DllCall("IsWindow", "Ptr", hwnd, "Int")
        } catch {
            return false
        }
    }

    _imageWindowExists() {
        if !this.imageHwnd
            return false
        try return DllCall("IsWindow", "Ptr", this.imageHwnd, "Int") != 0
        catch
            return false
    }

    _forgetWindow() {
        this.window := ""
        this.imageHwnd := 0
        this.windowVisible := false
        this.windowCreatedTick := 0
    }

    _dropStaleWindow() {
        if this.window == ""
            return

        if !this._windowExists() {
            this._forgetWindow()
            return
        }

        ; ImageShow creates the real image window as a child. If that child is
        ; gone while the parent GUI survives, the user sees only BackColor,
        ; i.e. the small white rectangle observed in long-running sessions.
        if !this._imageWindowExists()
            this.RemoveWindow()
    }

    _shouldHealthRefresh() {
        if (this.window == "" or !this.windowVisible or !this.windowCreatedTick)
            return false
        return (this._tick() - this.windowCreatedTick) >= this.healthRefreshPeriod
    }

    _tick() {
        return DllCall("GetTickCount64", "UInt64")
    }

    _hasValidState() {
        if (this.current.image == "" or !this.current.image)
            return false
        if (this.current.x == "" or this.current.y == "")
            return false
        return true
    }

    _hasImageChanged() {
        if (this.current.name != this.prev.name or this.current.image != this.prev.image)
            return true
        if (this.current.image != "" and FileExist(this.current.image)) {
            modTime := FileGetTime(this.current.image)
            if (this.current.HasOwnProp("modTime") and this.current.modTime != modTime) {
                this.current.modTime := modTime
                return true
            }
            this.current.modTime := modTime
        }
        return false
    }

    _canSkipRepaint(imageChanged) {
        if (this.window == "" or !this.windowVisible or !this._windowExists() or !this._imageWindowExists())
            return false
        return (this.current.x == this.prev.x and
            this.current.y == this.prev.y and
            !imageChanged)
    }

    _loadDimensions(imageChanged) {
        if (!imageChanged and this.current.w > 0 and this.current.h > 0)
            return true

        try {
            sourceW := ImageWidth(this.current.image)
            sourceH := ImageHeight(this.current.image)
            this.current.w := Max(1, Round(sourceW * this.scale))
            this.current.h := Max(1, Round(sourceH * this.scale))
            return true
        } catch {
            this.Clear()
            return false
        }
    }

    _ensureWindow() {
        this._dropStaleWindow()
        if this.window != ""
            return true

        try {
            this._initWindow()
            return true
        } catch {
            this._forgetWindow()
            return false
        }
    }

    _initWindow() {
        if (this.window != "")
            this.RemoveWindow()

        sizeConstraints := " +MinSize" this.current.w "x" this.current.h
            . " +MaxSize" this.current.w "x" this.current.h

        ; The flag image fills the whole overlay window, so a color-key is not
        ; needed. Apply one uniform alpha to the complete overlay instead. This
        ; avoids the mouse-overlay edge case where TransColor + alpha could make
        ; a 100% setting vanish on some Windows 11 compositions.
        this.window := Gui("+LastFound -Caption +AlwaysOnTop +ToolWindow -Border -DPIScale -Resize +E0x20" sizeConstraints)
        this.window.MarginX := 0
        this.window.MarginY := 0
        this.window.Title := ""
        this.window.BackColor := this.bgColor

        display := this.window.Add("Text", "xm+0")
        display.move(, , this.current.w, this.current.h)

        windowStyles := WS_CHILD | WS_VISIBLE | WS_EX_LAYERED
        this.imageHwnd := ImageShow(this.current.image, , [0, 0, this.current.w, this.current.h], windowStyles, , display.hwnd)
        if !this._imageWindowExists()
            throw Error("Image overlay child window was not created")

        alpha := Max(0, Min(255, Round(this.opacity)))
        WinSetTransparent(alpha, this.window)
        this.windowCreatedTick := this._tick()
    }

    _showAtPosition() {
        this._dropStaleWindow()
        if this.window == ""
            return

        halfHeight := Floor(this.current.h / 2)
        posX := this.current.x + this.margin.x
        posY := this.current.y - halfHeight + this.margin.y
        this.window.Show("X" posX " Y" posY " AutoSize NA")
        this.windowVisible := true
    }
}

; Window style constants
WS_CHILD := 0x40000000
WS_VISIBLE := 0x10000000
WS_EX_LAYERED := 0x8000000
