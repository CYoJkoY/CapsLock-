#Requires AutoHotkey v2.0

class CustomMenu {
    static menuGui := ""
    static menuHwnd := 0
    static items := []
    static lastHoveredEntry := ""
    static hoverTimer := ""
    static outsideTimer := ""

    static itemH := 34
    static sepH := 9
    static menuW := 400

    static ShowWithItems(x, y, itemsArray) {
        this.Hide()
        this.items := this.NormalizeItems(itemsArray)
        this.lastHoveredEntry := ""
        this.BuildAndShow(x, y)
    }

    static NormalizeItems(itemsArray) {
        out := []

        for entry in itemsArray {
            if !IsObject(entry)
                continue

            if entry.HasProp("isSep") && entry.isSep {
                out.Push({ isSep: true })
                continue
            }

            label := entry.HasProp("label") ? String(entry.label) : ""
            callback := entry.HasProp("callback") ? entry.callback : ""

            out.Push({
                isSep: false,
                label: this.ClipLabel(label, 46),
                callback: callback,
                bgCtrl: "",
                txtCtrl: ""
            })
        }

        return out
    }

    static BuildAndShow(x, y) {
        totalH := 16

        for entry in this.items
            totalH += entry.isSep ? this.sepH : this.itemH

        menuW := this.menuW
        menuH := totalH

        myGui := Gui("+AlwaysOnTop -Caption +ToolWindow +Border +E0x20")
        myGui.BackColor := AppState.THEME_SURFACE

        curY := 8

        for entry in this.items {
            if entry.isSep {
                myGui.Add(
                    "Text",
                    "x12 y" (curY + 3) " w" (menuW - 24) " h1 Background" AppState.THEME_BORDER
                )
                curY += this.sepH
                continue
            }

            bgCtrl := myGui.Add(
                "Text",
                "x4 y" curY " w" (menuW - 8) " h" this.itemH " +0x0100 Background" AppState.THEME_SURFACE
            )

            myGui.SetFont("s10 c" AppState.THEME_FG, AppState.THEME_FONT)

            txtCtrl := myGui.Add(
                "Text",
                "x16 y" (curY + 8) " w" (menuW - 40) " h20 +0x0109 Background" AppState.THEME_SURFACE,
                entry.label
            )

            entry.bgCtrl := bgCtrl
            entry.txtCtrl := txtCtrl

            bgCtrl.OnEvent("Click", ObjBindMethod(this, "InvokeAndClose", entry.callback))
            txtCtrl.OnEvent("Click", ObjBindMethod(this, "InvokeAndClose", entry.callback))

            curY += this.itemH
        }

        posX := Clamp(x, 5, A_ScreenWidth - menuW - 5)
        posY := Clamp(y, 5, A_ScreenHeight - menuH - 5)

        this.menuGui := myGui
        this.menuHwnd := myGui.Hwnd

        if this.hoverTimer == ""
            this.hoverTimer := ObjBindMethod(this, "CheckHover")

        if this.outsideTimer == ""
            this.outsideTimer := ObjBindMethod(this, "CheckOutsideClick")

        SetTimer(this.hoverTimer, 30)
        SetTimer(this.outsideTimer, 100)

        myGui.Show("x" posX " y" posY " w" menuW " h" menuH " NoActivate")
        ThemeHelper.ApplyImmersiveDarkMode(this.menuHwnd)
    }

    static CheckHover() {
        if !IsObject(this.menuGui)
            return

        MouseGetPos(, , , &hCtrl, 2)
        hovered := ""

        if hCtrl {
            for entry in this.items {
                if entry.isSep
                    continue

                try {
                    if entry.bgCtrl.Hwnd == hCtrl || entry.txtCtrl.Hwnd == hCtrl {
                        hovered := entry
                        break
                    }
                }
            }
        }

        if hovered != this.lastHoveredEntry {
            this.SetHover(this.lastHoveredEntry, false)
            this.SetHover(hovered, true)
            this.lastHoveredEntry := hovered
        }
    }

    static SetHover(entry, isHover) {
        if !IsObject(entry) || entry.isSep
            return

        bg := isHover ? AppState.THEME_ELEVATED : AppState.THEME_SURFACE
        fg := isHover ? AppState.THEME_ACCENT_GLOW : AppState.THEME_FG

        try {
            entry.bgCtrl.Opt("Background" bg)
            entry.txtCtrl.Opt("Background" bg)
            entry.txtCtrl.Opt("c" fg)
        }
    }

    static InvokeAndClose(cb, *) {
        this.Hide()

        if IsObject(cb)
            cb.Call()
    }

    static CheckOutsideClick() {
        if !IsObject(this.menuGui) || !WinExist("ahk_id " this.menuHwnd) {
            if this.outsideTimer != ""
                SetTimer(this.outsideTimer, 0)
            return
        }

        MouseGetPos(&mx, &my)

        try {
            WinGetPos(&wx, &wy, &ww, &wh, "ahk_id " this.menuHwnd)

            if (mx < wx || mx > wx + ww || my < wy || my > wy + wh) && GetKeyState("LButton", "P")
                this.Hide()
        } catch {
            this.Hide()
        }
    }

    static Hide() {
        if this.hoverTimer != ""
            SetTimer(this.hoverTimer, 0)

        if this.outsideTimer != ""
            SetTimer(this.outsideTimer, 0)

        if IsObject(this.menuGui) {
            try this.menuGui.Destroy()
        }

        this.menuGui := ""
        this.menuHwnd := 0
        this.items := []
        this.lastHoveredEntry := ""
    }

    static ClipLabel(text, maxUnits := 46) {
        text := RegExReplace(String(text), "[\r\n\t\v\f]+", " ")
        text := Trim(text)

        if text == ""
            text := "(empty)"

        out := ""
        units := 0

        Loop Parse, text {
            ch := A_LoopField
            w := Ord(ch) > 127 ? 2 : 1

            if units + w > maxUnits {
                out .= "…"
                break
            }

            out .= ch
            units += w
        }

        return StrReplace(out, "&", "&&")
    }
}
