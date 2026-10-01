#Requires AutoHotkey v2.0

; ---------------------------------------------------------------------------
; Dynamic Zoom (CapsLock + Z)
;
; Full-screen magnification: while the effect is running, the whole screen
; shows a magnified view of the desktop immediately around the physical
; cursor. At a factor of n the visible area is the n-th part of the desktop
; that surrounds the pointer, so only the ring of content around the pointer
; is on screen and everything in it is n times bigger.
;
; Why the Windows Magnification API
; ---------------------------------
; The obvious implementation - GetDC(NULL) plus StretchBlt - cannot work here.
; The overlay covers the screen, so the source rectangle lies entirely inside
; the overlay: a plain screen capture would capture the overlay itself and
; feed it straight back into the view.
;
; The Magnification API avoids that class of problem entirely. A magnifier
; control is a live view of the composed desktop that keeps refreshing itself,
; and MagSetWindowFilterList() lets the effect exclude its own window from the
; magnified image, which removes the feedback loop. It also gives the two
; other properties this effect needs without extra work:
;
;   * the content is live, so video, animation and scrolling keep updating
;     while the cursor is still - no polling of the content is required;
;   * magnification is done by the compositor, so the per-frame cost is a
;     single MagSetWindowSource() call, and an idle cursor produces no work at
;     all.
;
; Why the view follows the pointer instead of centring it
; -------------------------------------------------------
; The pointer is drawn by the system at its real screen position, on top of
; the magnified image, and that position is also where mouse input is
; reported. The view therefore has to show the desktop point that is under the
; pointer *at the pointer*, so that what the user aims at is what a click
; hits. The magnifier control maps the top-left corner of its source rectangle
; onto the top-left corner of its client area and scales by the factor, so a
; desktop point p ends up on screen at
;
;     screenX(p) = viewLeft + (p - sourceLeft) * factor
;
; Solving screenX(cursor) = cursor for the source rectangle gives
;
;     sourceLeft = cursor - (cursor - viewLeft) / factor
;
; which is what _SetSource() computes. The same expression keeps the source
; rectangle inside the view for every cursor position (sourceLeft >= viewLeft
; and sourceLeft + viewWidth / factor <= viewRight), so no clamping, no
; unpainted strips and no black edges are needed, and no input transform is
; required either: the pointer never moves relative to the content underneath
; it, so clicks land where they are drawn. Near the edge of the desktop the
; pointer consequently sits off the centre of the screen and the view shows the
; part of the ring that exists on that side - the same trade-off the system
; magnifier makes, and the alternative, centring the pointer and shifting the
; content under it, would make every click land somewhere else.
;
; Requirements
; ------------
; Magnification requires Windows 8 or later and a layered host window. When
; MagInitialize() fails the effect refuses to start and says so, rather than
; silently falling back to a flickering capture loop.
;
; Input behaviour
; ---------------
; The host window and the magnifier control are both click-through, so the
; applications underneath keep receiving mouse and keyboard input normally.
;
; Nothing underneath is modified, so deactivation only has to destroy the two
; windows and release the API - there is no stale frame left behind because
; the effect never wrote to the desktop in the first place.
; ---------------------------------------------------------------------------
class Zoom {
    ; Magnifier window styles.
    static WS_CHILD := 0x40000000
    static WS_VISIBLE := 0x10000000
    static MW_FILTERMODE_EXCLUDE := 0

    ; --- Runtime state ---
    static Active := false
    static HostGui := ""
    static MagHwnd := 0
    static MagInitialized := false
    static ActiveCfg := ""
    static TimerCallback := ""
    static LastX := ""
    static LastY := ""

    ; The desktop rectangle the view covers (every monitor, in physical
    ; pixels). It is re-read on every update so that a resolution change or a
    ; monitor being plugged in or removed re-lays out the view instead of
    ; leaving a stale overlay behind.
    static ViewX := 0
    static ViewY := 0
    static ViewW := 0
    static ViewH := 0

    ; The source rectangle currently handed to the magnifier control; kept so
    ; that an unchanged frame can be skipped.
    static SourceX := ""
    static SourceY := ""
    static SourceW := 0
    static SourceH := 0

    static IsActive() => this.Active

    ; -----------------------------------------------------------------------
    ; Configuration
    ; -----------------------------------------------------------------------

    static Config() {
        factor := Clamp(this._Int(AppState.ZoomFactor, 3), 2, 16)

        activation := StrLower(Trim(String(AppState.ZoomActivation)))
        if (activation != "hold" && activation != "toggle")
            activation := "toggle"

        interval := Clamp(this._Int(AppState.ZoomUpdateInterval, 16), 8, 100)

        return {
            factor: factor,
            activation: activation,
            interval: interval
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

        this.ViewW := 0
        this.ViewH := 0
        this._ReadView()

        ; The host is created off-screen and only enters the desktop once the
        ; first source rectangle is in place, so it never flashes an empty
        ; black screen at the user.
        host := ""
        try {
            host := CursorFx.CreateOverlay()
            host.BackColor := "0x000000"

            offScreen := Format(
                "x{} y{} w{} h{} NoActivate",
                this.ViewX - this.ViewW, this.ViewY - this.ViewH, this.ViewW, this.ViewH
            )
            host.Show(offScreen)

            ; The magnifier control may only be hosted in a layered window, and
            ; a layered window has to be made opaque explicitly, otherwise the
            ; desktop underneath shows through the magnified image.
            CursorFx.SetAlpha(host.Hwnd, 255)
        } catch {
            try {
                if IsObject(host)
                    host.Destroy()
            } catch {
            }
            this._ReleaseMag()
            return
        }

        mag := this._CreateMagChild(host.Hwnd, this.ViewW, this.ViewH)

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
        this.ActiveCfg := cfg
        this.LastX := ""
        this.LastY := ""
        this.SourceX := ""
        this.SourceY := ""

        ; Click-through has to be applied to the magnifier control as well: the
        ; host's WS_EX_TRANSPARENT only removes the host from hit-testing, and
        ; the child covers the whole host.
        this._SetChildClickThrough(mag)

        this._SetTransform(cfg.factor)

        ; Excluding our own window from the magnified image is what removes the
        ; feedback loop. Without it the view would magnify itself.
        this._ApplyFilter(host.Hwnd)

        this.Active := true
        this.TimerCallback := ObjBindMethod(this, "_Tick")
        SetTimer(this.TimerCallback, cfg.interval)

        try
            this._Update(true)
        catch {
        }
    }

    static Stop(*) {
        if !this.Active
            return

        this.Active := false

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

        if IsObject(this.HostGui) {
            try this.HostGui.Destroy()
            catch {
            }
            this.HostGui := ""
        }

        this._ReleaseMag()

        this.ActiveCfg := ""
        this.LastX := ""
        this.LastY := ""
        this.SourceX := ""
        this.SourceY := ""
        this.SourceW := 0
        this.SourceH := 0
        this.ViewW := 0
        this.ViewH := 0
    }

    ; Re-apply settings while the view is open. Only the factor can change
    ; without the view being rebuilt, and it is applied by re-scaling the
    ; magnifier control and recomputing the source rectangle.
    static Refresh(*) {
        if !this.Active
            return

        cfg := this.Config()
        this.ActiveCfg := cfg

        this._SetTransform(cfg.factor)

        try
            this._Update(true)
        catch {
        }
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

        resized := this._ReadView()

        if (!force && !resized && mx == this.LastX && my == this.LastY)
            return

        this.LastX := mx
        this.LastY := my

        cfg := IsObject(this.ActiveCfg) ? this.ActiveCfg : this.Config()

        ; The source rectangle is set before the view is moved or resized, so
        ; the window never shows a frame of the previous view.
        this._SetSource(mx, my, cfg, force || resized)

        if (force || resized)
            this._Layout()
    }

    ; Read the bounding rectangle of every monitor. Returns true when it
    ; differs from the one the current view was built for.
    static _ReadView() {
        x := 0
        y := 0
        w := 0
        h := 0
        CursorFx.VirtualScreen(&x, &y, &w, &h)

        changed := (w != this.ViewW || h != this.ViewH || x != this.ViewX || y != this.ViewY)

        this.ViewX := x
        this.ViewY := y
        this.ViewW := w
        this.ViewH := h

        return changed
    }

    ; Size the host and the magnifier control to the view rectangle and put
    ; the view in place. The magnifier control fills the host's client area, so
    ; its client origin is the view origin and the mapping in _SetSource()
    ; holds.
    static _Layout() {
        if IsObject(this.HostGui) {
            try
                this.HostGui.Move(this.ViewX, this.ViewY, this.ViewW, this.ViewH)
            catch {
            }
        }

        if this.MagHwnd {
            try
                DllCall(
                    "user32\SetWindowPos",
                    "Ptr", this.MagHwnd,
                    "Ptr", 0,
                    "Int", 0, "Int", 0,
                    "Int", this.ViewW, "Int", this.ViewH,
                    "UInt", 0x0002 | 0x0004 | 0x0010   ; SWP_NOMOVE|SWP_NOZORDER|SWP_NOACTIVATE
                )
            catch {
            }
        }
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

    static _CreateMagChild(hostHwnd, width, height) {
        hInst := 0
        try
            hInst := DllCall("kernel32\GetModuleHandleW", "Ptr", 0, "Ptr")
        catch
            hInst := 0

        style := this.WS_CHILD | this.WS_VISIBLE

        try {
            return DllCall(
                "user32\CreateWindowExW",
                "UInt", 0,
                "Str", "Magnifier",
                "Str", "MagnifierWindow",
                "UInt", style,
                "Int", 0,
                "Int", 0,
                "Int", width,
                "Int", height,
                "Ptr", hostHwnd,
                "Ptr", 0,
                "Ptr", hInst,
                "Ptr", 0,
                "Ptr"
            )
        } catch
            return 0
    }

    static _SetChildClickThrough(hwnd) {
        try {
            exStyle := DllCall("user32\GetWindowLongPtrW", "Ptr", hwnd, "Int", -20, "Ptr")
            exStyle := exStyle | 0x20        ; WS_EX_TRANSPARENT
            DllCall("user32\SetWindowLongPtrW", "Ptr", hwnd, "Int", -20, "Ptr", exStyle, "Ptr")
        } catch {
        }
    }

    static _ApplyFilter(hostHwnd) {
        if (!this.MagHwnd || !hostHwnd)
            return false

        exclude := Buffer(A_PtrSize, 0)
        NumPut("Ptr", hostHwnd, exclude, 0)

        try
            return DllCall(
                "magnification\MagSetWindowFilterList",
                "Ptr", this.MagHwnd,
                "UInt", this.MW_FILTERMODE_EXCLUDE,
                "Int", 1,
                "Ptr", exclude.Ptr,
                "Int"
            ) != 0
        catch
            return false
    }

    ; Scale the source rectangle by the magnification factor. The matrix is a
    ; 3x3 float matrix with the scale on the diagonal; everything else stays
    ; zero, so the magnified image is anchored at the client area's origin.
    static _SetTransform(factor) {
        if !this.MagHwnd
            return false

        matrix := Buffer(36, 0)
        NumPut("Float", factor, matrix, 0)
        NumPut("Float", factor, matrix, 16)
        NumPut("Float", 1.0, matrix, 32)

        try
            return DllCall(
                "magnification\MagSetWindowTransform",
                "Ptr", this.MagHwnd,
                "Ptr", matrix.Ptr,
                "Int"
            ) != 0
        catch
            return false
    }

    ; Point the magnifier control at the region of the desktop to show. The
    ; visible region is the view divided by the factor, held still under the
    ; cursor (see the header comment for the derivation).
    static _SetSource(mx, my, cfg, force := false) {
        if !this.MagHwnd
            return

        ; Rounded up so the scaled copy always covers the whole client area
        ; instead of leaving a strip of the (black) host window at the right or
        ; bottom edge.
        width := Ceil(this.ViewW / cfg.factor)
        height := Ceil(this.ViewH / cfg.factor)

        left := Round(mx - (mx - this.ViewX) / cfg.factor)
        top := Round(my - (my - this.ViewY) / cfg.factor)

        ; Rounding can push the rectangle a pixel past the edge of the desktop;
        ; pull it back instead of sampling pixels that do not exist.
        left := Clamp(left, this.ViewX, Max(this.ViewX, this.ViewX + this.ViewW - width))
        top := Clamp(top, this.ViewY, Max(this.ViewY, this.ViewY + this.ViewH - height))

        if (!force) {
            if (left == this.SourceX && top == this.SourceY
                && width == this.SourceW && height == this.SourceH)
                return
        }

        rect := Buffer(16, 0)
        NumPut("Int", left, rect, 0)
        NumPut("Int", top, rect, 4)
        NumPut("Int", left + width, rect, 8)
        NumPut("Int", top + height, rect, 12)

        applied := false
        try
            applied := DllCall(
                "magnification\MagSetWindowSource",
                "Ptr", this.MagHwnd,
                "Ptr", rect.Ptr,
                "Int"
            ) != 0
        catch
            applied := false

        if !applied
            return

        this.SourceX := left
        this.SourceY := top
        this.SourceW := width
        this.SourceH := height

        ; Ask the control for a frame of the new rectangle. The image is erased
        ; by the control itself, so the background is not painted over it.
        try
            DllCall("user32\InvalidateRect", "Ptr", this.MagHwnd, "Ptr", 0, "Int", 0)
    }
}
