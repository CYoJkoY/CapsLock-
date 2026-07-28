#Requires AutoHotkey v2.0

class CustomMenu {
    static menuGui := ""
    static menuHwnd := 0
    static items := []
    static selectedIndex := 0
    static callbackMap := Map()
    static lastHoveredEntry := ""

    static Show(x, y) {
        this.Hide()
        this.items := []
        this.callbackMap := Map()
        this.selectedIndex := 0
        this.lastHoveredEntry := ""

        this.AddItem("📋 " Lang("MENU_HISTORY"), (*) => ShowFullHistoryGui())
        this.AddSeparator()
        this.AddItem("📁 " Lang("MENU_FOLDER"), (*) => OpenHistoryFolder())
        this.AddItem("🚫 " Lang("MENU_IGNORE"), (*) => SetIgnorePatterns())
        this.AddSeparator()
        if AppState.AutoCleanEnabled
            this.AddItem("✅ " Lang("MENU_AUTOCLEAN_ON"), (*) => ToggleAutoClean())
        else
            this.AddItem("⬜ " Lang("MENU_AUTOCLEAN_OFF"), (*) => ToggleAutoClean())
        this.AddItem("🔄 " Lang("MENU_RELOAD"), (*) => Reload())
        this.AddSeparator()
        this.AddItem("❌ " Lang("MENU_EXIT"), (*) => ExitApp())

        this._BuildAndShow(x, y)
    }

    static ShowWithItems(x, y, itemsArray) {
        this.Hide()
        this.items := itemsArray
        this.callbackMap := Map()
        this.selectedIndex := 0
        this.lastHoveredEntry := ""
        this._BuildAndShow(x, y)
    }

    static _BuildAndShow(x, y) {
        myGui := Gui("+AlwaysOnTop -Caption +ToolWindow +Border +E0x20")
        myGui.BackColor := AppState.THEME_SURFACE

        itemH := 34
        sepH := 9
        totalH := 8
        maxWidth := 0

        for entry in this.items {
            if entry.isSep {
                totalH += sepH
            } else {
                totalH += itemH
                textLen := StrLen(entry.label) * 9 + 40
                if (textLen > maxWidth)
                    maxWidth := textLen
            }
        }

        totalH += 8
        if (maxWidth < 200)
            maxWidth := 200
        if (maxWidth > 420)
            maxWidth := 420

        menuW := maxWidth
        menuH := totalH

        curY := 8
        itemIndex := 0
        for entry in this.items {
            if entry.isSep {
                myGui.Add("Text", "x12 y" curY+3 " w" (menuW - 24) " h1 Background" AppState.THEME_BORDER)
                curY += sepH
            } else {
                itemIndex++
                bgCtrl := myGui.Add("Text", "x4 y" curY " w" (menuW - 8) " h" itemH " Background" AppState.THEME_SURFACE)
                myGui.SetFont("s10 c" AppState.THEME_FG, AppState.THEME_FONT)
                txtCtrl := myGui.Add("Text", "x16 y" curY+7 " w" (menuW - 32) " Background" AppState.THEME_SURFACE, entry.label)

                entry.bgCtrl := bgCtrl
                entry.txtCtrl := txtCtrl

                cb := entry.callback
                bgCtrl.OnEvent("Click", (*) => this.InvokeAndClose(cb))
                txtCtrl.OnEvent("Click", (*) => this.InvokeAndClose(cb))

                curY += itemH
            }
        }

        posX := x
        posY := y
        if (posX + menuW > A_ScreenWidth)
            posX := A_ScreenWidth - menuW - 5
        if (posY + menuH > A_ScreenHeight)
            posY := A_ScreenHeight - menuH - 5
        if (posX < 0)
            posX := 5
        if (posY < 0)
            posY := 5

        this.hoverTimer := ObjBindMethod(this, "CheckHover")
        SetTimer(this.hoverTimer, 30)

        myGui.Show("x" posX " y" posY " w" menuW " h" menuH " NoActivate")
        ThemeHelper.ApplyImmersiveDarkMode(myGui.Hwnd)

        this.menuGui := myGui
        this.menuHwnd := myGui.Hwnd

        SetTimer(() => this.CheckOutsideClick(), 100)
    }

    static CheckHover() {
        if !IsObject(this.menuGui)
            return
        MouseGetPos(, , , &hCtrl, 2)
        hoveredEntry := ""
        if (hCtrl) {
            for item in this.items {
                if item.isSep
                    continue
                try {
                    if (item.bgCtrl.Hwnd == hCtrl || item.txtCtrl.Hwnd == hCtrl) {
                        hoveredEntry := item
                        break
                    }
                }
            }
        }
        if (hoveredEntry != this.lastHoveredEntry) {
            if IsObject(this.lastHoveredEntry) {
                try this.SetHover(this.lastHoveredEntry.bgCtrl, this.lastHoveredEntry.txtCtrl, false)
            }
            if IsObject(hoveredEntry) {
                try this.SetHover(hoveredEntry.bgCtrl, hoveredEntry.txtCtrl, true)
            }
            this.lastHoveredEntry := hoveredEntry
        }
    }

    static AddItem(label, callback) {
        this.items.Push({label: label, callback: callback, isSep: false})
    }

    static AddSeparator() {
        this.items.Push({label: "", callback: "", isSep: true})
    }

    static SetHover(bgCtrl, txtCtrl, isHover) {
        try {
            if isHover {
                bgCtrl.Opt("Background" AppState.THEME_ELEVATED)
                txtCtrl.Opt("Background" AppState.THEME_ELEVATED)
                txtCtrl.Opt("c" AppState.THEME_ACCENT_GLOW)
            } else {
                bgCtrl.Opt("Background" AppState.THEME_SURFACE)
                txtCtrl.Opt("Background" AppState.THEME_SURFACE)
                txtCtrl.Opt("c" AppState.THEME_FG)
            }
        }
    }

    static InvokeAndClose(cb) {
        this.Hide()
        if IsObject(cb)
            cb.Call()
    }

    static CheckOutsideClick() {
        if !IsObject(this.menuGui) || !WinExist("ahk_id " this.menuHwnd) {
            SetTimer(() => this.CheckOutsideClick(), 0)
            return
        }
        MouseGetPos(&mx, &my)
        try {
            WinGetPos(&wx, &wy, &ww, &wh, "ahk_id " this.menuHwnd)
            if (mx < wx || mx > wx + ww || my < wy || my > wy + wh) {
                if GetKeyState("LButton", "P") {
                    this.Hide()
                    SetTimer(() => this.CheckOutsideClick(), 0)
                }
            }
        } catch {
            this.Hide()
            SetTimer(() => this.CheckOutsideClick(), 0)
        }
    }

    static Hide() {
        SetTimer(() => this.CheckOutsideClick(), 0)
        if this.HasProp("hoverTimer") && this.hoverTimer != "" {
            SetTimer(this.hoverTimer, 0)
            this.hoverTimer := ""
        }
        if IsObject(this.menuGui) {
            try this.menuGui.Destroy()
        }
        this.menuGui := ""
        this.menuHwnd := 0
        this.lastHoveredEntry := ""
    }
}
