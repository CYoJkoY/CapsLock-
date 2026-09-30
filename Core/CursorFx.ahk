#Requires AutoHotkey v2.0

; ---------------------------------------------------------------------------
; Shared plumbing for the cursor-centred visual effects
; (Spotlight and Dynamic Zoom).
;
; Both effects are full-screen overlays that follow the physical cursor, so
; they need the same four things:
;
;   1. the virtual-screen rectangle, which spans every monitor;
;   2. the cursor position in physical pixels rather than DPI-virtualized
;      coordinates, so the overlay stays aligned at any scaling and on
;      mixed-DPI setups;
;   3. an overlay window that is top-most, click-through, and unable to take
;      focus;
;   4. GDI region helpers for the cut-out shapes.
;
; Keeping them here means the two effects cannot drift apart on any of those
; details.
; ---------------------------------------------------------------------------
class CursorFx {
    ; WS_EX_TRANSPARENT / WS_EX_NOACTIVATE / WS_EX_LAYERED.
    static EX_TRANSPARENT := 0x20
    static EX_NOACTIVATE  := 0x08000000
    static EX_LAYERED     := 0x80000

    ; --- Geometry ---------------------------------------------------------

    ; Bounding rectangle of every monitor, in physical pixels.
    static VirtualScreen(&x, &y, &w, &h) {
        x := 0
        y := 0
        w := A_ScreenWidth
        h := A_ScreenHeight

        try {
            x := SysGet(76)     ; SM_XVIRTUALSCREEN
            y := SysGet(77)     ; SM_YVIRTUALSCREEN
            w := SysGet(78)     ; SM_CXVIRTUALSCREEN
            h := SysGet(79)     ; SM_CYVIRTUALSCREEN
        } catch {
        }

        if (w <= 0)
            w := A_ScreenWidth
        if (h <= 0)
            h := A_ScreenHeight
    }

    ; Physical cursor position. GetPhysicalCursorPos is used instead of
    ; GetCursorPos so the result is already in the same physical coordinate
    ; space that the overlay windows are positioned in.
    static CursorPos(&x, &y) {
        x := 0
        y := 0

        point := Buffer(8, 0)

        try {
            if !DllCall("GetPhysicalCursorPos", "Ptr", point, "Int")
                return false

            x := NumGet(point, 0, "Int")
            y := NumGet(point, 4, "Int")
            return true
        } catch
            return false
    }

    ; --- Windows ----------------------------------------------------------

    ; An overlay window that never intercepts input and never takes focus:
    ;   WS_EX_TRANSPARENT - hit-testing skips the window entirely, so clicks
    ;                       and wheel events reach whatever is underneath;
    ;   WS_EX_NOACTIVATE  - showing the window does not activate it;
    ;   -DPIScale         - coordinates are physical pixels, matching the
    ;                       values returned by CursorPos() and VirtualScreen().
    ; "clickThrough" adds WS_EX_TRANSPARENT. Effects that offer an explicit
    ; interaction mode pass false so the overlay can receive input instead.
    static CreateOverlay(extra := "", clickThrough := true) {
        options := "-DPIScale +AlwaysOnTop -Caption +ToolWindow"
            . " +E0x" Format("{:x}", this.EX_NOACTIVATE)

        if clickThrough
            options .= " +E0x" Format("{:x}", this.EX_TRANSPARENT)

        if (extra != "")
            options .= " " extra

        return Gui(options)
    }

    ; Constant alpha for a WS_EX_LAYERED window (0 = invisible, 255 = opaque).
    static SetAlpha(hwnd, alpha) {
        alpha := Clamp(Integer(alpha), 0, 255)

        try
            return DllCall(
                "user32\SetLayeredWindowAttributes",
                "Ptr", hwnd,
                "UInt", 0,
                "UChar", alpha,
                "UInt", 2,          ; LWA_ALPHA
                "Int"
            ) != 0
        catch
            return false
    }

    ; --- Regions ----------------------------------------------------------

    ; Region covering one of the supported cut-out shapes.
    ;
    ; "corner" is the corner *radius* in pixels and is only used by the
    ; rounded shape. CreateRoundRectRgn() takes the width and height of the
    ; ellipse that forms the corners, i.e. the diameter, so it is doubled
    ; here.
    static CreateShapeRegion(shape, left, top, right, bottom, corner := 0) {
        try {
            switch shape {
                case "circle":
                    return DllCall("gdi32\CreateEllipticRgn",
                        "Int", left, "Int", top, "Int", right, "Int", bottom,
                        "Ptr")

                case "rounded":
                    cr := Clamp(Integer(corner), 0, Min(right - left, bottom - top) // 2)
                    return DllCall("gdi32\CreateRoundRectRgn",
                        "Int", left, "Int", top, "Int", right, "Int", bottom,
                        "Int", cr * 2, "Int", cr * 2,
                        "Ptr")

                default:
                    return DllCall("gdi32\CreateRectRgn",
                        "Int", left, "Int", top, "Int", right, "Int", bottom,
                        "Ptr")
            }
        } catch
            return 0
    }

    ; Signed-distance style half-width of the shape at a given row offset.
    ;
    ; Returns the horizontal half-extent of {shape with half-size "extent" and
    ; corner radius "corner"} at vertical offset dy, or -1 when the row misses
    ; the shape. Used by the effects to restrict per-pixel work to the rows
    ; that actually intersect the shape.
    static HalfWidthAt(shape, extent, corner, dy) {
        ady := Abs(dy)

        if (ady > extent)
            return -1

        if (shape == "circle")
            return Sqrt(extent * extent - dy * dy)

        if (shape == "square")
            return extent

        ; rounded: straight edge inside the corner centres, circular arc
        ; outside them.
        inner := extent - corner
        if (corner <= 0 || ady <= inner)
            return extent

        off := ady - inner
        sq := corner * corner - off * off
        if (sq < 0)
            sq := 0

        return inner + Sqrt(sq)
    }
}
