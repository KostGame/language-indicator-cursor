; Reliable native overlay renderer for the floating language flags.
#requires AutoHotkey v2.0

class ImagePainter {
    __New() {
        this.window := ""
        this.picture := ""
        this.pictureHwnd := 0
        this.windowVisible := false
        this.windowCreatedTick := 0
        this.windowTitle := "LanguageIndicatorOverlay"
        this.healthRefreshPeriod := 10000
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

    HealthCheck() {
        if this.window == ""
            return

        this._dropStaleWindow()
        if (this.window != "" and this._shouldHealthRefresh())
            this.RemoveWindow()
    }

    ForceRebuild() {
        this.RemoveWindow()
    }

    RemoveWindow() {
        if this.window != ""
            try this.window.Destroy()
        this._forgetWindow()
    }

    HideWindow() {
        if this.window == ""
            return

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

    _pictureExists() {
        if !this.pictureHwnd
            return false
        try return DllCall("IsWindow", "Ptr", this.pictureHwnd, "Int") != 0
        catch
            return false
    }

    _forgetWindow() {
        this.window := ""
        this.picture := ""
        this.pictureHwnd := 0
        this.windowVisible := false
        this.windowCreatedTick := 0
    }

    _dropStaleWindow() {
        if this.window == ""
            return

        if !this._windowExists() or !this._pictureExists()
            this.RemoveWindow()
    }

    _shouldHealthRefresh() {
        if (this.window == "" or !this.windowCreatedTick)
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
        if (this.window == "" or !this.windowVisible or !this._windowExists() or !this._pictureExists())
            return false
        return (this.current.x == this.prev.x and
            this.current.y == this.prev.y and
            !imageChanged)
    }

    _loadDimensions(imageChanged) {
        if (!imageChanged and this.current.w > 0 and this.current.h > 0)
            return true

        try {
            sourceW := 0, sourceH := 0
            if !this._readBitmapDimensions(this.current.image, &sourceW, &sourceH)
                return false
            this.current.w := Max(1, Round(sourceW * this.scale))
            this.current.h := Max(1, Round(sourceH * this.scale))
            return true
        } catch {
            this.Clear()
            return false
        }
    }

    _readBitmapDimensions(path, &width, &height) {
        imageType := 0
        handle := LoadPicture(path, "", &imageType)
        if !handle
            return false

        try {
            bm := Buffer(A_PtrSize == 8 ? 32 : 24, 0)
            if !DllCall("GetObject", "Ptr", handle, "Int", bm.Size, "Ptr", bm, "Int")
                return false
            width := NumGet(bm, 4, "Int")
            height := Abs(NumGet(bm, 8, "Int"))
            return width > 0 and height > 0
        } finally {
            ; LoadPicture reports 0 for HBITMAP, 1 for HICON and 2 for HCURSOR.
            if imageType == 0
                DllCall("DeleteObject", "Ptr", handle)
            else
                DllCall("DestroyIcon", "Ptr", handle)
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
        if this.window != ""
            this.RemoveWindow()

        this.window := Gui("-Caption +AlwaysOnTop +ToolWindow -Border -DPIScale -Resize +E0x20")
        this.window.MarginX := 0
        this.window.MarginY := 0
        this.window.Title := this.windowTitle

        pictureOptions := "x0 y0 w" . this.current.w . " h" . this.current.h
        this.picture := this.window.Add("Picture", pictureOptions, this.current.image)
        this.pictureHwnd := this.picture.Hwnd
        this.windowCreatedTick := this._tick()
    }

    _showAtPosition() {
        this._dropStaleWindow()
        if this.window == ""
            return

        halfHeight := Floor(this.current.h / 2)
        posX := this.current.x + this.margin.x
        posY := this.current.y - halfHeight + this.margin.y
        showOptions := "X" . posX . " Y" . posY . " W" . this.current.w . " H" . this.current.h . " NA"
        this.window.Show(showOptions)

        alpha := Max(0, Min(255, Round(this.opacity)))
        WinSetTransparent(alpha, "ahk_id " . this.window.Hwnd)
        this.windowVisible := true
    }
}
