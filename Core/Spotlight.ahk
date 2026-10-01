#Requires AutoHotkey v2.0

; ---------------------------------------------------------------------------
; Spotlight (issue #75)
;
; A screen-sized translucent dark layer with a clear region that follows the
; physical cursor, so attention stays on the area around the pointer while the
; rest of the desktop remains visible through the dim layer.
;
; Rendering model
; ---------------
; Two overlay windows cooperate so the effect is both cheap and artifact free:
;
;   1. Dim layer   - a full-screen black window at constant alpha, clipped by a
;                    window region that removes the cut-out shape at the
;                    cursor. Because the hole is a *region*, the area inside it
;                    is genuinely absent from the window: fully clear and fully
;                    hit-test transparent, not merely "less dark".
;
;   2. Feather layer - a small square window, sized to the cut-out plus the
;                    softness, carrying a per-pixel alpha bitmap that ramps
;                    from transparent at the clear radius to the full dim
;                    alpha at the outer edge. It is rendered once per
;                    configuration change and then only *moved*, which is what
;                    keeps a soft edge affordable.
;
; The two are exact complements: the dim layer's hole ends at the outer radius,
; and the feather's alpha drops to zero at the same radius, so the sum of the
; two is continuous across the seam and no ring artifact appears.
;
; Input behaviour
; ---------------
; Both windows are WS_EX_TRANSPARENT (hit-testing skips them) and
; WS_EX_NOACTIVATE (showing them cannot take focus), so mouse and keyboard
; input reaches the applications underneath unchanged. No window beneath the
; overlay is modified in any way, so deactivation only has to destroy the two
; overlays.
; ---------------------------------------------------------------------------
class Spotlight {
    ; --- Runtime state ---
    static Active := false
    static DimGui := ""
    static FeatherGui := ""
    static ActiveCfg := ""
    static TimerCallback := ""
    static LastX := ""
    static LastY := ""

    ; --- Cached GDI state ---
    static HoleRegion := 0
    static HoleSignature := ""
    static HoleRegionX := 0
    static HoleRegionY := 0

    static FeatherHdc := 0
    static FeatherBitmap := 0
    static FeatherPrevBitmap := 0
    static FeatherSignature := ""
    static FeatherSide := 0

    static BlendBuffer := ""
    static PointZero := ""

    ; Corner radius of the rounded shape, as a fraction of its half-size.
    static RoundedCornerRatio := 0.45

    static IsActive() => this.Active

    ; -----------------------------------------------------------------------
    ; Configuration
    ; -----------------------------------------------------------------------

    ; Every value is clamped here, so a hand-edited Config.ini can never put
    ; the renderer into a state it cannot draw.
    static Config() {
        radius := Clamp(this._Int(AppState.SpotlightRadius, 180), 40, 900)
        softness := Clamp(this._Int(AppState.SpotlightSoftness, 60), 0, 250)
        darkness := Clamp(this._Int(AppState.SpotlightDarkness, 55), 5, 95)

        shape := StrLower(Trim(String(AppState.SpotlightShape)))
        if (shape != "circle" && shape != "rounded" && shape != "square")
            shape := "circle"

        interval := Clamp(this._Int(AppState.SpotlightUpdateInterval, 16), 8, 100)

        return {
            radius: radius,
            softness: softness,
            darkness: darkness,
            shape: shape,
            interval: interval,
            alpha: Round(darkness / 100 * 255),
            outer: radius + softness
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
        mode := StrLower(Trim(String(AppState.SpotlightActivation)))

        if (mode == "hold")
            this.Start()
        else
            this.Toggle()
    }

    static HandleUp(*) {
        mode := StrLower(Trim(String(AppState.SpotlightActivation)))

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

        vx := 0
        vy := 0
        vw := 0
        vh := 0
        CursorFx.VirtualScreen(&vx, &vy, &vw, &vh)

        if (vw <= 0 || vh <= 0)
            return

        ; The two cursor effects would fight over the same pixels.
        try {
            if Zoom.IsActive()
                Zoom.Stop()
        } catch {
        }

        outer := cfg.outer
        side := outer * 2

        if !this._EnsureBuffers()
            return

        dim := ""
        try {
            dim := CursorFx.CreateOverlay("+E0x80000")
            dim.BackColor := "0x000000"
            dim.Show("x" vx " y" vy " w" vw " h" vh " NoActivate")
        } catch {
            try {
                if IsObject(dim)
                    dim.Destroy()
            } catch {
            }
            return
        }

        CursorFx.SetAlpha(dim.Hwnd, cfg.alpha)

        this.DimGui := dim
        this.FeatherGui := ""
        this.ActiveCfg := cfg
        this.LastX := ""
        this.LastY := ""

        if (cfg.softness > 0) {
            feather := ""
            try {
                feather := CursorFx.CreateOverlay("+E0x80000")
                feather.Show("x" (vx - side) " y" vy " w" side " h" side " NoActivate")
            } catch {
                feather := ""
            }

            if IsObject(feather) {
                if this._PrepareFeather(feather, cfg)
                    this.FeatherGui := feather
                else
                    try feather.Destroy()
            }
        }

        this.Active := true
        this.TimerCallback := ObjBindMethod(this, "_Tick")
        SetTimer(this.TimerCallback, cfg.interval)
        this._Update(true)
    }

    ; Tear the effect down. Nothing underneath the overlay was ever modified,
    ; so removing the two windows fully restores the desktop.
    static Stop(*) {
        if !this.Active
            return

        try {
            if IsObject(this.TimerCallback)
                SetTimer(this.TimerCallback, 0)
        } catch {
        }
        this.TimerCallback := ""

        if IsObject(this.FeatherGui) {
            try this.FeatherGui.Destroy()
            catch {
            }
            this.FeatherGui := ""
        }

        if IsObject(this.DimGui) {
            try this.DimGui.Destroy()
            catch {
            }
            this.DimGui := ""
        }

        this._DestroyFeatherBitmap()

        if this.HoleRegion {
            try DllCall("gdi32\DeleteObject", "Ptr", this.HoleRegion)
            catch {
            }
            this.HoleRegion := 0
            this.HoleSignature := ""
        }

        this.Active := false
        this.ActiveCfg := ""
        this.LastX := ""
        this.LastY := ""
    }

    ; Re-apply the current settings without blinking the effect off and on.
    static Refresh(*) {
        if !this.Active
            return

        cfg := this.Config()
        this.ActiveCfg := cfg

        ; Force the cached hole region to be rebuilt with the new geometry.
        this.HoleSignature := ""

        if IsObject(this.DimGui)
            CursorFx.SetAlpha(this.DimGui.Hwnd, cfg.alpha)

        side := cfg.outer * 2

        if (cfg.softness <= 0) {
            if IsObject(this.FeatherGui) {
                try this.FeatherGui.Destroy()
                catch {
                }
                this.FeatherGui := ""
            }
            this._DestroyFeatherBitmap()
        } else {
            if !IsObject(this.FeatherGui) {
                try {
                    this.FeatherGui := CursorFx.CreateOverlay("+E0x80000")
                } catch {
                    this.FeatherGui := ""
                }
            }

            if IsObject(this.FeatherGui) {
                ; Re-showing with explicit geometry resizes the window, which
                ; UpdateLayeredWindow has to match.
                try
                    this.FeatherGui.Show("x-4000 y-4000 w" side " h" side " NoActivate")
                catch {
                }

                if !this._PrepareFeather(this.FeatherGui, cfg) {
                    try this.FeatherGui.Destroy()
                    catch {
                    }
                    this.FeatherGui := ""
                }
            }
        }

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

        ; Frame pacing: an idle cursor produces no work at all, so leaving the
        ; effect on costs nothing while the pointer is still.
        if (!force && mx == this.LastX && my == this.LastY)
            return

        this.LastX := mx
        this.LastY := my

        cfg := IsObject(this.ActiveCfg) ? this.ActiveCfg : this.Config()
        outer := cfg.outer

        if IsObject(this.DimGui) {
            region := this._BuildDimRegion(mx, my, cfg)

            if region {
                applied := false
                try
                    applied := DllCall(
                        "user32\SetWindowRgn",
                        "Ptr", this.DimGui.Hwnd,
                        "Ptr", region,
                        "Int", 1,
                        "Int"
                    ) != 0
                catch
                    applied := false

                ; The system owns the region only once SetWindowRgn succeeds.
                if !applied
                    try DllCall("gdi32\DeleteObject", "Ptr", region)
            }
        }

        if IsObject(this.FeatherGui) {
            try
                this.FeatherGui.Move(mx - outer, my - outer)
            catch {
            }
        }
    }

    ; -----------------------------------------------------------------------
    ; Dim layer region
    ; -----------------------------------------------------------------------

    ; Full virtual screen minus the cut-out at the cursor, in window-relative
    ; coordinates (the overlay sits at the virtual screen origin).
    static _BuildDimRegion(mx, my, cfg) {
        vx := 0
        vy := 0
        vw := 0
        vh := 0
        CursorFx.VirtualScreen(&vx, &vy, &vw, &vh)

        hx := mx - vx
        hy := my - vy
        outer := cfg.outer
        corner := Round(outer * this.RoundedCornerRatio)
        signature := cfg.shape "|" outer

        if (!this.HoleRegion || this.HoleSignature != signature) {
            if this.HoleRegion
                DllCall("gdi32\DeleteObject", "Ptr", this.HoleRegion)

            this.HoleRegion := CursorFx.CreateShapeRegion(
                cfg.shape,
                hx - outer, hy - outer, hx + outer, hy + outer,
                corner
            )
            this.HoleSignature := signature
            this.HoleRegionX := hx
            this.HoleRegionY := hy
        } else if (hx != this.HoleRegionX || hy != this.HoleRegionY) {
            ; Moving an existing region is far cheaper than rebuilding it.
            DllCall(
                "gdi32\OffsetRgn",
                "Ptr", this.HoleRegion,
                "Int", hx - this.HoleRegionX,
                "Int", hy - this.HoleRegionY,
                "Int"
            )
            this.HoleRegionX := hx
            this.HoleRegionY := hy
        }

        if !this.HoleRegion
            return 0

        screen := DllCall("gdi32\CreateRectRgn", "Int", 0, "Int", 0, "Int", vw, "Int", vh, "Ptr")
        if !screen
            return 0

        combined := DllCall("gdi32\CreateRectRgn", "Int", 0, "Int", 0, "Int", 0, "Int", 0, "Ptr")
        if !combined {
            DllCall("gdi32\DeleteObject", "Ptr", screen)
            return 0
        }

        ; RGN_DIFF: the screen rectangle with the cut-out removed.
        DllCall(
            "gdi32\CombineRgn",
            "Ptr", combined,
            "Ptr", screen,
            "Ptr", this.HoleRegion,
            "Int", 4,
            "Int"
        )
        DllCall("gdi32\DeleteObject", "Ptr", screen)

        return combined
    }

    ; -----------------------------------------------------------------------
    ; Feather layer
    ; -----------------------------------------------------------------------

    static _EnsureBuffers() {
        if IsObject(this.BlendBuffer) && IsObject(this.PointZero)
            return true

        try {
            ; BLENDFUNCTION for UpdateLayeredWindow:
            ;   BlendOp = AC_SRC_OVER, SourceConstantAlpha = 255 (use the
            ;   per-pixel values), AlphaFormat = AC_SRC_ALPHA.
            blend := Buffer(8, 0)
            NumPut("UChar", 0, blend, 0)
            NumPut("UChar", 0, blend, 1)
            NumPut("UChar", 255, blend, 2)
            NumPut("UChar", 1, blend, 3)

            this.BlendBuffer := blend
            this.PointZero := Buffer(8, 0)
            return true
        } catch
            return false
    }

    static _PrepareFeather(feather, cfg) {
        if !this._BuildFeatherBitmap(cfg)
            return false

        try {
            if !DllCall(
                "user32\UpdateLayeredWindow",
                "Ptr", feather.Hwnd,
                "Ptr", 0,                   ; hdcDst  - default palette
                "Ptr", 0,                   ; pptDst  - keep current position
                "Ptr", 0,                   ; psize   - keep current size
                "Ptr", this.FeatherHdc,
                "Ptr", this.PointZero.Ptr,  ; pptSrc  - (0, 0)
                "UInt", 0,                  ; crKey
                "Ptr", this.BlendBuffer.Ptr,
                "UInt", 2,                  ; ULW_ALPHA
                "Int"
            )
                return false
        } catch
            return false

        this.FeatherSide := cfg.outer * 2
        return true
    }

    static _BuildFeatherBitmap(cfg) {
        side := cfg.outer * 2
        if (side < 8)
            side := 8

        signature := cfg.shape "|" cfg.radius "|" cfg.softness "|" cfg.alpha "|" side

        ; The gradient only depends on the configuration, so a cursor move
        ; never has to repaint it.
        if (signature == this.FeatherSignature && this.FeatherBitmap)
            return true

        this._DestroyFeatherBitmap()

        hdcScreen := 0
        hdc := 0
        bmp := 0

        try {
            hdcScreen := DllCall("user32\GetDC", "Ptr", 0, "Ptr")
            hdc := DllCall("gdi32\CreateCompatibleDC", "Ptr", hdcScreen, "Ptr")
            if !hdc
                throw Error("CreateCompatibleDC failed")

            stride := side * 4

            ; Zero-filled: for a black overlay the premultiplied RGB is zero
            ; everywhere, so only the alpha byte ever needs writing.
            pixels := Buffer(stride * side, 0)
            this._PaintFeather(pixels, side, cfg)

            bmi := Buffer(40, 0)
            NumPut("UInt", 40, bmi, 0)   ; biSize
            NumPut("Int", side, bmi, 4)   ; biWidth
            NumPut("Int", -side, bmi, 8)   ; biHeight (negative = top-down)
            NumPut("UShort", 1, bmi, 12)  ; biPlanes
            NumPut("UShort", 32, bmi, 14)  ; biBitCount
            NumPut("UInt", 0, bmi, 16)  ; biCompression = BI_RGB

            bmp := DllCall("gdi32\CreateCompatibleBitmap", "Ptr", hdc, "Int", side, "Int", side, "Ptr")
            if !bmp
                throw Error("CreateCompatibleBitmap failed")

            if !DllCall(
                "gdi32\SetDIBits",
                "Ptr", hdc,
                "Ptr", bmp,
                "UInt", 0,
                "UInt", side,
                "Ptr", pixels.Ptr,
                "Ptr", bmi.Ptr,
                "UInt", 0,                  ; DIB_RGB_COLORS
                "Int"
            )
                throw Error("SetDIBits failed")

            prev := DllCall("gdi32\SelectObject", "Ptr", hdc, "Ptr", bmp, "Ptr")

            this.FeatherHdc := hdc
            this.FeatherBitmap := bmp
            this.FeatherPrevBitmap := prev
            this.FeatherSignature := signature
            this.FeatherSide := side
            return true
        } catch {
            if bmp
                try DllCall("gdi32\DeleteObject", "Ptr", bmp)
            if hdc
                try DllCall("gdi32\DeleteDC", "Ptr", hdc)

            this.FeatherHdc := 0
            this.FeatherBitmap := 0
            this.FeatherPrevBitmap := 0
            this.FeatherSignature := ""
            this.FeatherSide := 0
            return false
        } finally {
            if hdcScreen
                try DllCall("user32\ReleaseDC", "Ptr", 0, "Ptr", hdcScreen)
        }
    }

    static _DestroyFeatherBitmap() {
        ; Restore the previous bitmap first: a DC still holding a selected
        ; bitmap cannot be deleted safely.
        if this.FeatherHdc {
            if this.FeatherPrevBitmap
                try DllCall("gdi32\SelectObject", "Ptr", this.FeatherHdc, "Ptr", this.FeatherPrevBitmap, "Ptr")
            try DllCall("gdi32\DeleteDC", "Ptr", this.FeatherHdc)
        }

        if this.FeatherBitmap
            try DllCall("gdi32\DeleteObject", "Ptr", this.FeatherBitmap)

        this.FeatherHdc := 0
        this.FeatherBitmap := 0
        this.FeatherPrevBitmap := 0
        this.FeatherSignature := ""
        this.FeatherSide := 0
    }

    ; Writes the radial alpha ramp. Only rows and columns that intersect the
    ; feather band are visited, which keeps the rebuild to a few tens of
    ; thousands of pixels instead of the whole square.
    static _PaintFeather(pixels, side, cfg) {
        radius := cfg.radius
        softness := cfg.softness
        alpha := cfg.alpha
        shape := cfg.shape
        outer := cfg.outer

        stride := side * 4
        centre := outer
        cornerOuter := Round(outer * this.RoundedCornerRatio)

        loop side {
            py := A_Index - 1
            dy := py - centre

            outerHalf := CursorFx.HalfWidthAt(shape, outer, cornerOuter, dy)
            if (outerHalf < 0)
                continue

            xFrom := Max(0, Ceil(centre - outerHalf))
            xTo := Min(side - 1, Floor(centre + outerHalf))
            if (xTo < xFrom)
                continue

            rowBase := py * stride

            loop (xTo - xFrom + 1) {
                px := xFrom + A_Index - 1
                dx := px - centre

                m := this._BandParameter(shape, dx, dy, outer, radius, softness, cornerOuter)

                ; m <= 0 is the fully clear core, m > 1 is outside the band and
                ; already handled by the dim layer.
                if (m <= 0 || m > 1)
                    continue

                ; Smoothstep keeps the ramp from showing a visible crease at
                ; either end of the band.
                eased := m * m * (3 - 2 * m)
                a := Round(alpha * eased)

                if (a <= 0)
                    continue
                if (a > 255)
                    a := 255

                NumPut("UChar", a, pixels, rowBase + px * 4 + 3)
            }
        }
    }

    ; Normalized position inside the feather band: 0 on the clear boundary,
    ; 1 on the outer boundary.
    ;
    ; For every shape the inner boundary is the outer boundary offset inward by
    ; exactly "softness": a circle stays a circle, a square stays a square, and
    ; a rounded rectangle keeps its family with its corners reduced by the same
    ; amount. That is what makes the bitmap and the dim-layer hole agree.
    static _BandParameter(shape, dx, dy, outer, radius, softness, cornerOuter) {
        if (shape == "circle")
            return (Sqrt(dx * dx + dy * dy) - radius) / softness

        adx := Abs(dx)
        ady := Abs(dy)

        if (shape == "square")
            return (Max(adx, ady) - radius) / softness

        ; rounded: signed distance to the outer rounded rectangle.
        ux := Max(adx - (outer - cornerOuter), 0)
        uy := Max(ady - (outer - cornerOuter), 0)
        sd := Sqrt(ux * ux + uy * uy) - cornerOuter

        return 1 + sd / softness
    }
}
