; Displays images in transparent always-on-top windows for visual indicators
#requires AutoHotkey v2.0
#include ImagePut.ahk

class ImagePainter {
    __New() {
        this.bgColor := "ffffff"
        this.window := ""
        this.windowVisible := false
        this.margin := { x: 0, y: 0 }
        this.scale := 1
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

        imageChanged := this._hasImageChanged()

        if this._canSkipRepaint(imageChanged)
            return

        if (this.window != "" and imageChanged)
            this.RemoveWindow()

        if !this._loadDimensions(imageChanged)
            return

        if !this._ensureWindow()
            return

        this._showAtPosition()
    }

    RemoveWindow() {
        if this.window != "" {
            this.window.Destroy()
            this.window := ""
            this.windowVisible := false
        }
    }

    HideWindow() {
        if this.window != "" {
            this.window.Hide()
            this.windowVisible := false
        }
    }

    ; Private methods

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
        ; Check if file was modified (for external file changes)
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
        if (this.window == "" or !this.windowVisible)
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
        if this.window != ""
            return true

        try {
            this._initWindow()
            return true
        } catch {
            this.window := ""
            this.Clear()
            return false
        }
    }

    _initWindow() {
        if (this.window != "")
            this.window.Destroy()

        sizeConstraints := " +MinSize" this.current.w "x" this.current.h
            . " +MaxSize" this.current.w "x" this.current.h

        ; Transparent, always-on-top, click-through overlay with no activation.
        ; +E0x20 adds WS_EX_TRANSPARENT so the marker cannot steal mouse clicks.
        this.window := Gui("+LastFound -Caption +AlwaysOnTop +ToolWindow -Border -DPIScale -Resize +E0x20" sizeConstraints)
        this.window.MarginX := 0
        this.window.MarginY := 0
        this.window.Title := ""
        this.window.BackColor := this.bgColor
        WinSetTransColor(this.bgColor, this.window)

        ; Create dummy control for ImagePut
        display := this.window.Add("Text", "xm+0")
        display.move(, , this.current.w, this.current.h)

        ; ImagePut child window styles: WS_CHILD | WS_VISIBLE | WS_EX_LAYERED
        windowStyles := WS_CHILD | WS_VISIBLE | WS_EX_LAYERED
        ImageShow(this.current.image, , [0, 0, this.current.w, this.current.h], windowStyles, , display.hwnd)
    }

    _showAtPosition() {
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
