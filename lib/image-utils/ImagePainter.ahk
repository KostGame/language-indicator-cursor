; Reliable native overlay renderer for the floating language flags.
#requires AutoHotkey v2.0

#include ..\utils\RuntimeLog.ahk

class ImagePainter {
    __New() {
        this.window := ""
        this.picture := ""
        this.pictureHwnd := 0
        this.windowVisible := false
        this.windowCreatedTick := 0
        this.windowTitle := "LanguageIndicatorOverlay"
        this.hideBeforeMove := false
        this.rebuildOnLargeMove := false
        this.largeMoveThreshold := 64
        this.flushOnRebuild := false
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

        if (this.window != "" and (imageChanged or this._shouldHealthRefresh())) {
            if !this.RemoveWindow(this.flushOnRebuild)
                return
        }

        if this._canSkipRepaint(imageChanged)
            return

        if !this._loadDimensions(imageChanged)
            return

        if !this._ensureWindow()
            return

        this._showAtPosition()
    }

    HealthCheck() {
        currentHwnd := this._getWindowHwnd()
        this.PurgeOwnedOverlayWindows(currentHwnd, true)

        if this.window == ""
            return

        this._dropStaleWindow()
        if (this.window != "" and this._shouldHealthRefresh())
            this.RemoveWindow(this.flushOnRebuild)
    }

    ForceRebuild() {
        this.RemoveWindow(this.flushOnRebuild)
    }

    RemoveWindow(flushComposition := false) {
        hwnd := this._getWindowHwnd()

        if hwnd {
            ; Hide first so even a delayed destruction cannot keep painting.
            try this.window.Hide()
            try DllCall("user32\ShowWindow", "ptr", hwnd, "int", 0)
            this.windowVisible := false
        }

        if this.window != "" {
            try this.window.Destroy()
        }

        ; Gui.Destroy() may throw or return while a native HWND is still alive.
        ; Never drop our only handle until native destruction is confirmed.
        if hwnd and this._isNativeWindow(hwnd)
            this._destroyNativeWindow(hwnd)

        if hwnd and this._isNativeWindow(hwnd) {
            this.windowVisible := false
            RuntimeLogError(
                "ImagePainter.RemoveWindow",
                Error("Overlay HWND survived Gui.Destroy and DestroyWindow: " . hwnd . " title=" . this.windowTitle)
            )
            return false
        }

        this._forgetWindow()

        ; Sweep any earlier orphaned windows that no longer have an AHK object.
        cleanup := this.PurgeOwnedOverlayWindows(0, false)

        if flushComposition
            this.FlushComposition()

        return cleanup.remaining == 0
    }

    PurgeOwnedOverlayWindows(excludeHwnd := 0, flushComposition := false) {
        found := 0
        destroyed := 0
        remaining := 0

        for hwnd in this._ownedOverlayHwnds(excludeHwnd) {
            found += 1
            try DllCall("user32\ShowWindow", "ptr", hwnd, "int", 0)
            if this._destroyNativeWindow(hwnd)
                destroyed += 1
            else
                remaining += 1
        }

        if found > 0 and flushComposition
            this.FlushComposition()

        if remaining > 0 {
            RuntimeLogError(
                "ImagePainter.PurgeOwnedOverlayWindows",
                Error("Could not destroy " . remaining . " orphan overlay window(s) titled " . this.windowTitle)
            )
        }

        return { found: found, destroyed: destroyed, remaining: remaining }
    }

    FlushComposition() {
        try DllCall("dwmapi\DwmFlush", "Int")
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
            ; Do not forget a potentially live native window here.
            hwnd := this._getWindowHwnd()
            if hwnd
                try DllCall("user32\ShowWindow", "ptr", hwnd, "int", 0)
            this.windowVisible := false
            return
        }
        this.windowVisible := false
    }

    _getWindowHwnd() {
        if this.window == ""
            return 0
        try return this.window.Hwnd
        catch
            return 0
    }

    _isNativeWindow(hwnd) {
        if !hwnd
            return false
        try return DllCall("user32\IsWindow", "ptr", hwnd, "int") != 0
        catch
            return false
    }

    _destroyNativeWindow(hwnd) {
        if !this._isNativeWindow(hwnd)
            return true

        try DllCall("user32\DestroyWindow", "ptr", hwnd, "int")
        catch
            return false

        return !this._isNativeWindow(hwnd)
    }

    _ownedOverlayHwnds(excludeHwnd := 0) {
        result := []
        previousDetectHidden := A_DetectHiddenWindows
        try {
            DetectHiddenWindows(true)
            hwnds := WinGetList("ahk_pid " . A_Pid)

            for hwnd in hwnds {
                if (excludeHwnd and hwnd == excludeHwnd)
                    continue

                try title := WinGetTitle("ahk_id " . hwnd)
                catch
                    continue

                if title == this.windowTitle
                    result.Push(hwnd)
            }
        } catch {
            return result
        } finally {
            DetectHiddenWindows(previousDetectHidden)
        }
        return result
    }

    _windowExists() {
        return this._isNativeWindow(this._getWindowHwnd())
    }

    _pictureExists() {
        if !this.pictureHwnd
            return false
        try return DllCall("user32\IsWindow", "ptr", this.pictureHwnd, "int") != 0
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

        cleanup := this.PurgeOwnedOverlayWindows(0, true)
        if cleanup.remaining > 0
            return false

        try {
            this._initWindow()
            return true
        } catch as err {
            ; If construction failed after HWND creation, use the same verified
            ; destruction path instead of merely dropping the AHK object.
            this.RemoveWindow(true)
            RuntimeLogError("ImagePainter.InitWindow", err)
            return false
        }
    }

    _initWindow() {
        if this.window != "" {
            if !this.RemoveWindow(true)
                throw Error("Previous overlay window could not be destroyed")
        }

        this.window := Gui("-Caption +AlwaysOnTop +ToolWindow -Border -DPIScale -Resize +E0x20")
        this.window.MarginX := 0
        this.window.MarginY := 0
        this.window.Title := this.windowTitle

        pictureOptions := "x0 y0 w" . this.current.w . " h" . this.current.h
        this.picture := this.window.Add("Picture", pictureOptions, this.current.image)
        this.pictureHwnd := this.picture.Hwnd
        this.windowCreatedTick := this._tick()
    }

    _isLargeMove() {
        if !this.rebuildOnLargeMove or this.largeMoveThreshold <= 0
            return false
        if (this.current.x == "" or this.current.y == "" or this.prev.x == "" or this.prev.y == "")
            return false

        return Abs(this.current.x - this.prev.x) >= this.largeMoveThreshold
            or Abs(this.current.y - this.prev.y) >= this.largeMoveThreshold
    }

    _showAtPosition() {
        this._dropStaleWindow()
        if this.window == ""
            return

        movingVisibleWindow := this.windowVisible and
            (this.current.x != this.prev.x or this.current.y != this.prev.y)

        if movingVisibleWindow and this._isLargeMove() {
            if !this.RemoveWindow(true)
                return
            if !this._ensureWindow()
                return
        } else if this.hideBeforeMove and movingVisibleWindow {
            this.HideWindow()
            if this.window == ""
                return
        }

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
