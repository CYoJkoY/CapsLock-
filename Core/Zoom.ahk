#Requires AutoHotkey v2.0

; ---------------------------------------------------------------------------
; Dynamic Zoom (issue #76)
;
; A lens that follows the physical cursor and shows the desktop around it at an
; increased scale.
;
; Why the Windows Magnification API
; ---------------------------------
; The obvious implementation - GetDC(NULL) plus StretchBlt - cannot work here.
; The source rectangle is centred on the cursor and the lens is centred on the
; cursor, so the source rectangle lies entirely *inside* the lens window. A
; plain screen capture would therefore capture the lens window itself and feed
; it back into the lens.
;
; The Magnification API avoids that class of problem entirely: the magnifier
; control is a live window onto the composed desktop rather than a copy of it,
; and MagSetWindowFilterList() lets the effect exclude its own windows from the
; magnified image. It also gives the two properties the issue asks for without
; extra work:
;
;   * the content is live, so video, animation and scrolling keep updating
;     while the cursor is still - no polling of the content is required;
;   * magnification is done by the compositor, so the per-frame cost is two
;     window moves and one MagSetWindowSource() call, and an idle cursor
;     produces no work at all.
;
; Requirements
; ------------
; Magnification requires Windows 8 or later and a layered host window. When
; MagInitialize() fails the effect refuses to start and says so, rather than
; silently falling back to a flickering capture loop.
;
; Input behaviour
; ---------------
; By default the lens, its host and the border are all click-through, so the
; applications underneath keep receiving input normally. Turning click-through
; off gives the lens a real window that can take input, which is the "explicit
; interaction mode" the issue allows for.
;
; Nothing underneath is modified, so deactivation only has to destroy the three
; windows and release the API - there is no stale frame left behind because the
; lens never owned a copy of the screen in the first place.
; ---------------------------------------------------------------------------
class Zoom {
    ; Magnifier window styles.
    static WS_CHILD          := 0x40000000
    static WS_VISIBLE        := 0x10000000
    static MW_FILTERMODE_EXCLUDE := 0

    ; Corner radius of the rounded shape, as a fraction of the lens half-size.
    ; Kept identical to Spotlight so both effects render the same vocabulary of
    ; shapes.
    static RoundedCornerRatio := 0.45

    ; --- Runtime state ---
    static Active         := false
    static HostGui        := ""
    static MagHwnd        := 0
    static FrameGui       := ""
    static MagInitialized := false
    static ActiveCfg      := ""
    static TimerCallback  := ""
    static LastX          := ""
    static LastY          := ""

    static IsActive() => this.Active

    ; -----------------------------------------------------------------------
    ; Configuration
    ; -----------------------------------------------------------------------

    static Config() {
        factor := Clamp(this._Int(AppState.ZoomFactor, 3), 2, 16)
        lens := Clamp(this._Int(AppState.ZoomLensSize, 360), 120, 900)
        border := Clamp(this._Int(AppState.ZoomBorderWidth, 3), 0, 12)

        shape := StrLower(Trim(String(AppState.ZoomShape)))
        if (shape != "circle" && shape != "rounded" && shape != "square")
            shape := "circle"

        activation := StrLower(Trim(String(AppState.ZoomActivation)))
        if (activation != "hold" && activation != "toggle")
            activation := "toggle"

        interval := Clamp(this._Int(AppState.ZoomUpdateInterval, 16), 8, 100)

        return {
            factor: factor,
            lens: lens,
            border: border,
            shape: shape,
            activation: activation,
            interval: interval,
            clickThrough: AppState.ZoomClickThrough ? true : false
        }
    }

    static _Int(value, fallback) {
        try
            return Integer(value)
        catch
            return fallback
    }

    ; -----------------------------------------------------------------------
    ; Hotkey entry points
    ; -----------------------------------------------------------------------

    static HandleDown(*) {
        mode := StrLower(Trim(String(AppState.ZoomActivation)))

        if (mode == "hold")
            this.Start()
        else
            this.Toggle()
    }

    static HandleUp(*) {
        mode := StrLower(Trim(String(AppState.ZoomActivation)))

        if this.Active && mode == "hold"
            this.Stop()
    }

    static Toggle(*) {
        if this.Active
            this.Stop()
        else
            this.Start()
    }

    ; -----------------------------------------------------------------------
    ; Lifecycle
    ; -----------------------------------------------------------------------

    static Start(*) {
        if this.Active
            return

        cfg := this.Config()

        if !this._EnsureMag() {
            ShowToolTip(
                Lang(
                    "MSG_ZOOM_UNAVAILABLE",
                    "Dynamic Zoom needs the Windows Magnification API (Windows 8 or later)."
                ),
                2800
            )
            return
        }

        ; The two cursor effects would fight over the same pixels.
        try {
            if Spotlight.IsActive()
                Spotlight.Stop()
        } catch {
        }

        lens := cfg.lens

        host := ""
        try {
            host := CursorFx.CreateOverlay("+E0x80000", cfg.clickThrough)
            host.BackColor := "0x000000"
            host.Show("x-4000 y-4000 w" lens " h" lens " NoActivate")
        } catch {
            try {
                if IsObject(host)
                    host.Destroy()
            } catch {
            }
            this._ReleaseMag()
            return
        }

        mag := this._CreateMagChild(host.Hwnd, lens)

        if !mag {
            try host.Destroy()
            catch {
            }
            this._ReleaseMag()
            ShowToolTip(
                Lang("MSG_ZOOM_UNAVAILABLE", "Dynamic Zoom needs the Windows Magnification API (Windows 8 or later)."),
                2800
            )
            return
        }

        this.HostGui := host
        this.MagHwnd := mag
        this.FrameGui := ""
        this.ActiveCfg := cfg
        this.LastX := ""
        this.LastY := ""

        ; Click-through has to be applied to the magnifier child as well: the
        ; host's WS_EX_TRANSPARENT only removes the host from hit-testing, and
        ; the child covers the whole host.
        if cfg.clickThrough
            this._SetChildClickThrough(mag, true)

        this._ApplyRegion(host, cfg, "host")

        if (cfg.border > 0) {
            frame := ""
            try {
                frame := CursorFx.CreateOverlay()
                frame.BackColor := AppState.THEME_ACCENT
                frame.Show("x-4000 y-4000 w" lens " h" lens " NoActivate")
            } catch {
                frame := ""
            }

            if IsObject(frame) {
                if this._ApplyRegion(frame, cfg, "frame")
                    this.FrameGui := frame
                else
                    try frame.Destroy()
            }
        }

        ; Excluding our own windows from the magnified image is what removes
        ; the feedback loop. Without it the lens would magnify itself.
        this._ApplyFilter(host.Hwnd, IsObject(this.FrameGui) ? this.FrameGui.Hwnd : 0)

        this.Active := true
        this.TimerCallback := ObjBindMethod(this, "_Tick")
        SetTimer(this.TimerCallback, cfg.interval)
        this._Update(true)
    }

    static Stop(*) {
        if !this.Active
            return

        try {
            if IsObject(this.TimerCallback)
                SetTimer(this.TimerCallback, 0)
        } catch {
        }
        this.TimerCallback := ""

        ; Destroying the child first stops any further magnification before the
        ; host disappears, so no partially rendered frame can survive.
        if this.MagHwnd {
            try
                DllCall("user32\DestroyWindow", "Ptr", this.MagHwnd)
            catch {
            }
            this.MagHwnd := 0
        }

        if IsObject(this.FrameGui) {
            try this.FrameGui.Destroy()
            catch {
            }
            this.FrameGui := ""
        }

        if IsObject(this.HostGui) {
            try this.HostGui.Destroy()
            catch {
            }
            this.HostGui := ""
        }

        this._ReleaseMag()

        this.Active := false
        this.ActiveCfg := ""
        this.LastX := ""
        this.LastY := ""
    }

    ; Re-apply settings while running, or apply the current palette to a lens
    ; that is already open.
    static Refresh(*) {
        if !this.Active
            return

        cfg := this.Config()
        this.ActiveCfg := cfg

        if IsObject(this.HostGui) {
            try
                this.HostGui.Show("x-4000 y-4000 w" cfg.lens " h" cfg.lens " NoActivate")
            catch {
            }
            this._ApplyRegion(this.HostGui, cfg, "host")

            if this.MagHwnd {
                try
                    DllCall(
                        "user32\SetWindowPos",
                        "Ptr", this.MagHwnd,
                        "Ptr", 0,
                        "Int", 0, "Int", 0,
                        "Int", cfg.lens, "Int", cfg.lens,
                        "UInt", 0x0002 | 0x0004 | 0x0010   ; SWP_NOMOVE|SWP_NOZORDER|SWP_NOACTIVATE
                    )
                catch {
                }
                this._SetChildClickThrough(this.MagHwnd, cfg.clickThrough)
            }
        }

        if IsObject(this.FrameGui) && cfg.border <= 0 {
            try this.FrameGui.Destroy()
            catch {
            }
            this.FrameGui := ""
        }

        if (cfg.border > 0) {
            if !IsObject(this.FrameGui) {
                try {
                    this.FrameGui := CursorFx.CreateOverlay()
                } catch {
                    this.FrameGui := ""
                }
            }

            if IsObject(this.FrameGui) {
                this.FrameGui.BackColor := AppState.THEME_ACCENT
                try
                    this.FrameGui.Show("x-4000 y-4000 w" cfg.lens " h" cfg.lens " NoActivate")
                catch {
                }
                this._ApplyRegion(this.FrameGui, cfg, "frame")
            }
        }

        this._ApplyFilter(
            IsObject(this.HostGui) ? this.HostGui.Hwnd : 0,
            IsObject(this.FrameGui) ? this.FrameGui.Hwnd : 0
        )

        this._Update(true)
    }

    ; -----------------------------------------------------------------------
    ; Per-frame update
    ; -----------------------------------------------------------------------

    static _Tick(*) {
        if !this.Active {
            try {
                if IsObject(this.TimerCallback)
                    SetTimer(this.TimerCallback, 0)
            } catch {
            }
            this.TimerCallback := ""
            return
        }

        try
            this._Update()
        catch {
        }
    }

    static _Update(force := false) {
        if !this.Active
            return

        if !CursorFx.CursorPos(&mx, &my)
            return

        if (!force && mx == this.LastX && my == this.LastY)
            return

        this.LastX := mx
        this.LastY := my

        cfg := IsObject(this.ActiveCfg) ? this.ActiveCfg : this.Config()
        half := cfg.lens // 2

        ; The lens windows are centred on the cursor, so their clip regions are
        ; constant in window coordinates and never have to be rebuilt.
        if IsObject(this.HostGui) {
            try
                this.HostGui.Move(mx - half, my - half)
            catch {
            }
        }

        if IsObject(this.FrameGui) {
            try
                this.FrameGui.Move(mx - half, my - half)
            catch {
            }
        }

        this._SetSource(mx, my, cfg)
    }

    ; -----------------------------------------------------------------------
    ; Magnification API
    ; -----------------------------------------------------------------------

    static _EnsureMag() {
        if this.MagInitialized
            return true

        try {
            if !DllCall("LoadLibrary", "Str", "magnification.dll", "Ptr")
                return false

            if !DllCall("magnification\MagInitialize", "Int")
                return false
        } catch
            return false

        this.MagInitialized := true
        return true
    }

    static _ReleaseMag() {
        if !this.MagInitialized
            return

        try
            DllCall("magnification\MagUninitialize", "Int")
        catch {
        }

        this.MagInitialized := false
    }

    static _CreateMagChild(hostHwnd, size) {
        hInst := 0
        try
            hInst := DllCall("kernel32\GetModuleHandleW", "Ptr", 0, "Ptr")
        catch
            hInst := 0

        try {
            return DllCall(
                "user32\CreateWindowExW",
                "UInt", 0,
                "Str", "Magnifier",
                "Str", "MagnifierWindow",
                "UInt", this.WS_CHILD | this.WS_VISIBLE,
                "Int", 0,
                "Int", 0,
                "Int", size,
                "Int", size,
                "Ptr", hostHwnd,
                "Ptr", 0,
                "Ptr", hInst,
                "Ptr", 0,
                "Ptr"
            )
        } catch
            return 0
    }

    static _SetChildClickThrough(hwnd, enabled) {
        try {
            exStyle := DllCall("user32\GetWindowLongPtrW", "Ptr", hwnd, "Int", -20, "Ptr")

            if enabled
                exStyle := exStyle | 0x20
            else
                exStyle := exStyle & ~0x20

            DllCall("user32\SetWindowLongPtrW", "Ptr", hwnd, "Int", -20, "Ptr", exStyle, "Ptr")
        } catch {
        }
    }

    static _ApplyFilter(hostHwnd, frameHwnd) {
        if !this.MagHwnd
            return false

        exclude := []
        if hostHwnd
            exclude.Push(hostHwnd)
        if frameHwnd
            exclude.Push(frameHwnd)

        if !exclude.Length
            return false

        excludeBuffer := Buffer(exclude.Length * A_PtrSize, 0)
        for index, hwnd in exclude
            NumPut("Ptr", hwnd, excludeBuffer, (index - 1) * A_PtrSize)

        try
            return DllCall(
                "magnification\MagSetWindowFilterList",
                "Ptr", this.MagHwnd,
                "UInt", this.MW_FILTERMODE_EXCLUDE,
                "Int", exclude.Length,
                "Ptr", excludeBuffer.Ptr,
                "Int"
            ) != 0
        catch
            return false
    }

    ; Point the magnifier at the region around the cursor. The magnification
    ; factor is the lens size divided by the source size, and the control keeps
    ; rendering live content on its own afterwards.
    static _SetSource(mx, my, cfg) {
        if !this.MagHwnd
            return

        vx := 0
        vy := 0
        vw := 0
        vh := 0
        CursorFx.VirtualScreen(&vx, &vy, &vw, &vh)

        source := Round(cfg.lens / cfg.factor)
        if (source < 2)
            source := 2
        if (source > vw)
            source := vw
        if (source > vh)
            source := vh

        ; Keep the sampled rectangle on the desktop so the lens never shows
        ; undefined pixels past the screen edge.
        sx := Clamp(mx - source // 2, vx, Max(vx, vx + vw - source))
        sy := Clamp(my - source // 2, vy, Max(vy, vy + vh - source))

        rect := Buffer(16, 0)
        NumPut("Int", sx, rect, 0)
        NumPut("Int", sy, rect, 4)
        NumPut("Int", sx + source, rect, 8)
        NumPut("Int", sy + source, rect, 12)

        try
            DllCall("magnification\MagSetWindowSource", "Ptr", this.MagHwnd, "Ptr", rect.Ptr, "Int")
        catch {
        }
    }

    ; -----------------------------------------------------------------------
    ; Shaping
    ; -----------------------------------------------------------------------

    ; "host" clips the magnifier to the lens shape; "frame" leaves only the
    ; border ring, so the two together give a shaped lens with a shaped border.
    static _ApplyRegion(gui, cfg, kind) {
        lens := cfg.lens
        corner := Round(lens / 2 * this.RoundedCornerRatio)

        region := (kind == "frame")
            ? this._BuildFrameRegion(cfg, corner)
            : CursorFx.CreateShapeRegion(cfg.shape, 0, 0, lens, lens, corner)

        if !region
            return false

        applied := false

        try
            applied := DllCall(
                "user32\SetWindowRgn",
                "Ptr", gui.Hwnd,
                "Ptr", region,
                "Int", 1,
                "Int"
            ) != 0
        catch
            applied := false

        if !applied {
            try DllCall("gdi32\DeleteObject", "Ptr", region)
            return false
        }

        return true
    }

    static _BuildFrameRegion(cfg, corner) {
        lens := cfg.lens
        border := cfg.border

        outer := CursorFx.CreateShapeRegion(cfg.shape, 0, 0, lens, lens, corner)
        if !outer
            return 0

        if (border <= 0)
            return outer

        inner := CursorFx.CreateShapeRegion(
            cfg.shape,
            border, border,
            lens - border, lens - border,
            Max(corner - border, 0)
        )

        if !inner {
            DllCall("gdi32\DeleteObject", "Ptr", outer)
            return 0
        }

        combined := DllCall("gdi32\CreateRectRgn", "Int", 0, "Int", 0, "Int", 0, "Int", 0, "Ptr")

        if !combined {
            DllCall("gdi32\DeleteObject", "Ptr", outer)
            DllCall("gdi32\DeleteObject", "Ptr", inner)
            return 0
        }

        ; RGN_DIFF: the outer shape with the lens interior removed.
        DllCall(
            "gdi32\CombineRgn",
            "Ptr", combined,
            "Ptr", outer,
            "Ptr", inner,
            "Int", 4,
            "Int"
        )

        DllCall("gdi32\DeleteObject", "Ptr", outer)
        DllCall("gdi32\DeleteObject", "Ptr", inner)

        return combined
    }
}
