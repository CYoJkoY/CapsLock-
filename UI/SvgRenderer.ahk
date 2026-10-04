#Requires AutoHotkey v2.0

; Small dependency-free SVG renderer for the icon subset used by CapsLock-.
; AutoHotkey's native Picture control does not decode SVG consistently, so we
; parse the source at runtime and paint its vector primitives into a 32-bit
; GDI+ bitmap. SVG remains the runtime source; no generated PNG is involved.
class SvgRenderer {
    static _started := false
    static _bitmaps := Map()
    static _gdipToken := 0

    static Init() {
        if this._started
            return true
        si := Buffer(24, 0)
        NumPut("UInt", 1, si, 0)
        if DllCall("gdiplus\GdiplusStartup", "Ptr*", &token := 0, "Ptr", si, "Ptr", 0) != 0
            return false
        this._gdipToken := token
        this._started := true
        return true
    }

    static Render(path, width := 20, height := 20) {
        if !this.Init()
            return 0
        if !FileExist(path)
            return 0
        key := path "|" width "|" height
        if this._bitmaps.Has(key)
            return this._bitmaps[key]
        svg := FileRead(path)
        bitmap := 0
        graphics := 0
        if DllCall("gdiplus\GdipCreateBitmapFromScan0", "Int", width, "Int", height, "Int", 0, "Int", 0x26200A, "Ptr", 0, "Ptr*", &bitmap := 0) != 0
            return 0
        try {
            DllCall("gdiplus\GdipGetImageGraphicsContext", "Ptr", bitmap, "Ptr*", &graphics := 0)
            DllCall("gdiplus\GdipSetSmoothingMode", "Ptr", graphics, "Int", 4)
            this._Paint(svg, graphics, width, height)
            DllCall("gdiplus\GdipCreateHBITMAPFromBitmap", "Ptr", bitmap, "Ptr*", &hBitmap := 0, "UInt", 0)
            this._bitmaps[key] := hBitmap
            return hBitmap
        } finally {
            if graphics
                DllCall("gdiplus\GdipDeleteGraphics", "Ptr", graphics)
            if bitmap
                DllCall("gdiplus\GdipDisposeImage", "Ptr", bitmap)
        }
    }

    static _Paint(svg, graphics, width, height) {
        pos := 1
        while pos := RegExMatch(svg, "<rect\b[^>]*>", &m, pos) {
            tag := m[0], x := this._Attr(tag, "x", 0), y := this._Attr(tag, "y", 0)
            w := this._Attr(tag, "width", width), h := this._Attr(tag, "height", height)
            stroke := this._Color(this._Attr(tag, "stroke", "")), sw := this._Attr(tag, "stroke-width", 1)
            if stroke {
                pen := this._Pen(stroke, sw), DllCall("gdiplus\GdipDrawRectangle", "Ptr", graphics, "Ptr", pen, "Float", x, "Float", y, "Float", w, "Float", h), DllCall("gdiplus\GdipDeletePen", "Ptr", pen)
            }
            pos += StrLen(tag)
        }
        pos := 1
        while pos := RegExMatch(svg, "<circle\b[^>]*>", &m, pos) {
            tag := m[0], cx := this._Attr(tag, "cx", 0), cy := this._Attr(tag, "cy", 0), r := this._Attr(tag, "r", 0)
            stroke := this._Color(this._Attr(tag, "stroke", "")), sw := this._Attr(tag, "stroke-width", 1)
            if stroke {
                pen := this._Pen(stroke, sw), DllCall("gdiplus\GdipDrawEllipse", "Ptr", graphics, "Ptr", pen, "Float", cx-r, "Float", cy-r, "Float", r*2, "Float", r*2), DllCall("gdiplus\GdipDeletePen", "Ptr", pen)
            }
            pos += StrLen(tag)
        }
        pos := 1
        while pos := RegExMatch(svg, "<line\b[^>]*>", &m, pos) {
            tag := m[0], x1 := this._Attr(tag, "x1", 0), y1 := this._Attr(tag, "y1", 0), x2 := this._Attr(tag, "x2", 0), y2 := this._Attr(tag, "y2", 0)
            color := this._Color(this._Attr(tag, "stroke", "#A6382A")), sw := this._Attr(tag, "stroke-width", 1)
            pen := this._Pen(color, sw), DllCall("gdiplus\GdipDrawLine", "Ptr", graphics, "Ptr", pen, "Float", x1, "Float", y1, "Float", x2, "Float", y2), DllCall("gdiplus\GdipDeletePen", "Ptr", pen)
            pos += StrLen(tag)
        }
    }

    static _Attr(tag, name, fallback) {
        if RegExMatch(tag, "\b" name "=[\"']([^\"']+)", &m)
            return IsNumber(m[1]) ? Number(m[1]) : m[1]
        return fallback
    }
    static _Color(value) {
        if value == "" || value == "none"
            return 0
        value := RegExReplace(value, "^#")
        return 0xFF000000 | Integer("0x" value)
    }
    static _Pen(color, width) {
        DllCall("gdiplus\GdipCreatePen1", "UInt", color, "Float", width, "Int", 2, "Ptr*", &pen := 0)
        return pen
    }
}

OnExit((*) => SvgRenderer._gdipToken && DllCall("gdiplus\GdiplusShutdown", "Ptr", SvgRenderer._gdipToken))
