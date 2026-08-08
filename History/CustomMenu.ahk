#Requires AutoHotkey v2.0

; ============================================================================
; Global helpers (extracted from class to reduce size and increase reuse)
; ============================================================================

; Truncate text to fit within maxUnits display width units.
; ASCII = 1 unit, non‑ASCII (CJK, emoji, etc.) = 2 units.
ClipLabel(text, maxUnits := 46) {
    text := RegExReplace(String(text), "\s+", " ")
    text := Trim(text)
    if (text == "")
        text := "(empty)"

    ; Fast path: short enough to never need truncation
    if (StrLen(text) <= maxUnits // 2)
        return StrReplace(text, "&", "&&")

    out := ""
    units := 0
    Loop Parse, text {
        ch := A_LoopField
        w := (Ord(ch) > 127) ? 2 : 1
        if (units + w > maxUnits) {
            out .= "…"
            break
        }
        out .= ch
        units += w
    }

    return StrReplace(out, "&", "&&")
}

; Find monitor index containing screen point (x, y). Falls back to primary.
FindMonitorIndex(x, y) {
    Loop MonitorGetCount() {
        MonitorGet(A_Index, &mL, &mT, &mR, &mB)
        if (x >= mL && x < mR && y >= mT && y < mB)
            return A_Index
    }

    return MonitorGetPrimary()
}

; DPI scaling factor relative to 96 DPI (100% scaling).
GetDpiScale() {
    return Max(A_ScreenDPI, 96) / 96.0
}

; Vertical offset to align bottom‑left corner with tray icon click position.
GetAnchorOffset() {
    static BASE_OFFSET := 60   ; calibrated at 96 DPI
    return Round(BASE_OFFSET * GetDpiScale())
}

; ============================================================================
; CustomMenu class – main context menu with sub‑menu support
; ============================================================================

class CustomMenu {
    ; -------- Public properties --------
    static menuGui := ""
    static menuHwnd := 0
    static items := []
    static lastHoveredEntry := ""
    static hoverTimer := ""
    static outsideTimer := ""
    static itemH := 34
    static sepH := 9
    static menuW := 420
    static topPad := 16

    ; -------- Sub‑menu state (encapsulated) --------
    static Sub := {
        gui: "",
        hwnd: 0,
        items: [],
        lastHovered: "",
        parentEntry: ""
    }

    ; -------- Public entry points --------
    static ShowWithItems(x, y, itemsArray, anchorBottom := false) {
        this.Hide()
        this.items := this.NormalizeItems(itemsArray)
        this.lastHoveredEntry := ""
        this._BuildAndShow(x, y, anchorBottom)
    }

    static Hide() {
        this._HideSubMenu()
        if (this.hoverTimer != "")
            SetTimer(this.hoverTimer, 0)
        if (this.outsideTimer != "")
            SetTimer(this.outsideTimer, 0)
        if IsObject(this.menuGui)
            try this.menuGui.Destroy()
        this.menuGui := ""
        this.menuHwnd := 0
        this.items := []
        this.lastHoveredEntry := ""
    }

    ; -------- Item normalization --------
    static NormalizeItems(itemsArray) {
        out := []
        for entry in itemsArray {
            if !IsObject(entry)
                continue

            if (entry.HasProp("isSep") && entry.isSep) {
                out.Push({ isSep: true })
                continue
            }

            label := entry.HasProp("label") ? String(entry.label) : ""
            callback := entry.HasProp("callback") ? entry.callback : ""
            hasChildren := entry.HasProp("children") && IsObject(entry.children) && entry.children.Length > 0
            displayLabel := hasChildren ? ClipLabel(label, 46) . "  ▶" : ClipLabel(label, 52)
            outEntry := {
                isSep: false,
                label: displayLabel,
                callback: callback,
                bgCtrl: "",
                txtCtrl: ""
            }

            if hasChildren
                outEntry.children := entry.children

            out.Push(outEntry)
        }
        return out
    }

    static NormalizeSubItems(itemsArray) {
        out := []
        for entry in itemsArray {
            if !IsObject(entry)
                continue
            if (entry.HasProp("isSep") && entry.isSep) {
                out.Push({ isSep: true })
                continue
            }
            label := entry.HasProp("label") ? String(entry.label) : ""
            callback := entry.HasProp("callback") ? entry.callback : ""
            out.Push({
                isSep: false,
                label: ClipLabel(label, 44),
                callback: callback,
                bgCtrl: "",
                txtCtrl: ""
            })
        }
        return out
    }

    ; -------- Layout calculation --------
    static CalcLayout(items, baseItemH, baseSepH, baseTopPad) {
        totalH := baseTopPad
        for entry in items
            totalH += entry.isSep ? baseSepH : baseItemH

        maxAllowed := A_ScreenHeight * 0.75
        if (totalH > maxAllowed) {
            ratio := maxAllowed / totalH
            itemH := Max(Integer(baseItemH * ratio), 22)
            sepH := Max(Integer(baseSepH * ratio), 4)
            topPad := Max(Integer(baseTopPad * ratio), 6)
            totalH := topPad
            for entry in items
                totalH += entry.isSep ? sepH : itemH

            return { totalH: totalH, itemH: itemH, sepH: sepH, topPad: topPad }
        }
        return { totalH: totalH, itemH: baseItemH, sepH: baseSepH, topPad: baseTopPad }
    }

    ; -------- Main menu building --------
    static _BuildAndShow(x, y, anchorBottom) {
        if (this.items.Length == 0)
            return

        dims := this.CalcLayout(this.items, this.itemH, this.sepH, this.topPad)
        itemH := dims.itemH, sepH := dims.sepH, topPad := dims.topPad, totalH := dims.totalH
        menuW := this.menuW, menuH := totalH

        myGui := this._CreateMainGui(menuW, itemH, sepH, topPad)
        this.menuGui := myGui
        this.menuHwnd := myGui.Hwnd

        ; Apply bottom‑anchor offset
        if anchorBottom {
            offset := GetAnchorOffset()
            y := y - menuH - offset
        }

        ; Position and show
        this._PositionAndShow(myGui, x, y, menuW, menuH)
        ThemeHelper.ApplyImmersiveDarkMode(this.menuHwnd)

        ; Start timers
        if (this.hoverTimer == "")
            this.hoverTimer := ObjBindMethod(this, "_CheckHover")

        if (this.outsideTimer == "")
            this.outsideTimer := ObjBindMethod(this, "_CheckOutsideClick")

        SetTimer(this.hoverTimer, 50)
        SetTimer(this.outsideTimer, 150)
    }

    static _CreateMainGui(menuW, itemH, sepH, topPad) {
        myGui := Gui("+AlwaysOnTop -Caption +ToolWindow +Border")
        myGui.BackColor := AppState.THEME_SURFACE
        myGui.SetFont("s10 c" AppState.THEME_FG, AppState.THEME_FONT)

        curY := topPad // 2
        Loop this.items.Length {
            entry := this.items[A_Index]
            if entry.isSep {
                myGui.Add("Text", "x12 y" (curY + 3) " w" (menuW - 24) " h1 Background" AppState.THEME_BORDER)
                curY += sepH
                continue
            }

            bgCtrl := myGui.Add("Text", "x4 y" curY " w" (menuW - 8) " h" itemH " +0x0100 Background" AppState.THEME_SURFACE)
            txtCtrl := myGui.Add("Text", "x16 y" (curY + (itemH - 20) // 2) " w" (menuW - 40) " h20 +0x0100 Background" AppState.THEME_SURFACE, entry.label)
            entry.bgCtrl := bgCtrl
            entry.txtCtrl := txtCtrl

            if entry.HasProp("children") {
                cb := ObjBindMethod(this, "_ToggleSubMenu", entry)
            } else if entry.HasProp("callback") && IsObject(entry.callback) {
                cb := ObjBindMethod(this, "_InvokeAndClose", entry.callback)
            } else {
                curY += itemH
                continue
            }

            bgCtrl.OnEvent("Click", cb)
            txtCtrl.OnEvent("Click", cb)
            curY += itemH
        }

        return myGui
    }

    static _PositionAndShow(guiObj, x, y, w, h) {
        monIdx := FindMonitorIndex(x, y)
        MonitorGetWorkArea(monIdx, &waLeft, &waTop, &waRight, &waBottom)
        posX := Clamp(x, waLeft + 5, waRight - w - 5)
        posY := Clamp(y, waTop + 5, waBottom - h - 5)
        guiObj.Show("x" posX " y" posY " w" w " h" h " NoActivate")
    }

    ; -------- Sub‑menu management --------
    static _ToggleSubMenu(entry, *) {
        if (this.Sub.parentEntry == entry && this.Sub.gui != "") {
            this._HideSubMenu()
        } else {
            this._HideSubMenu()
            this._ShowSubMenu(entry)
        }
    }

    static _ShowSubMenu(parentEntry) {
        if !parentEntry.HasProp("children")
            return

        children := parentEntry.children
        if !IsObject(children) || children.Length == 0
            return

        ; Get parent entry screen position
        try {
            parentEntry.bgCtrl.GetPos(&px, &py, &pw, &ph)
            WinGetPos(&wx, &wy, , , "ahk_id " this.menuHwnd)
            px += wx
            py += wy
        } catch {
            return
        }

        subItems := this.NormalizeSubItems(children)
        if subItems.Length == 0
            return

        ; Layout
        subItemH := this.itemH
        subSepH := this.sepH
        subTopPad := 12
        subMenuW := 380
        dims := this.CalcLayout(subItems, subItemH, subSepH, subTopPad)
        subItemH := dims.itemH
        subSepH := dims.sepH
        subTopPad := dims.topPad
        subTotalH := dims.totalH

        ; Create sub‑menu GUI
        subGui := this._CreateSubGui(subItems, subMenuW, subItemH, subSepH, subTopPad)
        this.Sub.gui := subGui
        this.Sub.hwnd := subGui.Hwnd
        this.Sub.items := subItems
        this.Sub.parentEntry := parentEntry
        this._SetHover(parentEntry, true)  ; keep parent highlighted

        ; Position sub‑menu to the right, expanding upward by default
        subX := px + pw + 4
        subY := py + ph - subTotalH
        monIdx := FindMonitorIndex(subX, subY)
        MonitorGetWorkArea(monIdx, &waLeft, &waTop, &waRight, &waBottom)
        if (subX + subMenuW > waRight - 5)
            subX := px - subMenuW - 4

        if (subY < waTop + 5)
            subY := py
        subY := Clamp(subY, waTop + 5, waBottom - subTotalH - 5)

        subGui.Show("x" subX " y" subY " w" subMenuW " h" subTotalH " NoActivate")
        ThemeHelper.ApplyImmersiveDarkMode(this.Sub.hwnd)
    }

    static _CreateSubGui(subItems, menuW, itemH, sepH, topPad) {
        subGui := Gui("+AlwaysOnTop -Caption +ToolWindow +Border")
        subGui.BackColor := AppState.THEME_SURFACE
        subGui.SetFont("s10 c" AppState.THEME_FG, AppState.THEME_FONT)

        curY := topPad // 2
        Loop subItems.Length {
            entry := subItems[A_Index]
            if entry.isSep {
                subGui.Add("Text", "x12 y" (curY + 3) " w" (menuW - 24) " h1 Background" AppState.THEME_BORDER)
                curY += sepH
                continue
            }

            bgCtrl := subGui.Add("Text", "x4 y" curY " w" (menuW - 8) " h" itemH " +0x0100 Background" AppState.THEME_SURFACE)
            txtCtrl := subGui.Add("Text", "x16 y" (curY + (itemH - 20) // 2) " w" (menuW - 40) " h20 +0x0100 Background" AppState.THEME_SURFACE, entry.label)
            entry.bgCtrl := bgCtrl
            entry.txtCtrl := txtCtrl
            if entry.HasProp("callback") && IsObject(entry.callback) {
                cb := ObjBindMethod(this, "_InvokeSubAndClose", entry.callback)
                bgCtrl.OnEvent("Click", cb)
                txtCtrl.OnEvent("Click", cb)
            }

            curY += itemH
        }
        return subGui
    }

    static _HideSubMenu() {
        if (this.Sub.gui != "") {
            if (this.Sub.parentEntry != "" && IsObject(this.Sub.parentEntry))
                this._SetHover(this.Sub.parentEntry, false)

            try this.Sub.gui.Destroy()
            this.Sub.gui := ""
            this.Sub.hwnd := 0
            this.Sub.items := []
            this.Sub.lastHovered := ""
            this.Sub.parentEntry := ""
        }
    }

    ; -------- Hover and click handling --------
    static _CheckHover() {
        if !IsObject(this.menuGui)
            return

        MouseGetPos(, , , &hCtrl, 2)

        ; Check sub‑menu first
        if (this.Sub.hwnd && WinExist("ahk_id " this.Sub.hwnd)) {
            if (this._CheckSubMenuHover(hCtrl))
                return
        }

        ; Check main menu
        if (this._CheckMainMenuHover(hCtrl))
            return

        ; Mouse outside – close sub and clear main hover
        if (this.Sub.gui != "")
            this._HideSubMenu()

        if (this.lastHoveredEntry != "") {
            this._SetHover(this.lastHoveredEntry, false)
            this.lastHoveredEntry := ""
        }
    }

    static _CheckSubMenuHover(hCtrl) {
        subHovered := ""
        if hCtrl {
            Loop this.Sub.items.Length {
                entry := this.Sub.items[A_Index]
                if entry.isSep
                    continue

                try {
                    if (entry.bgCtrl.Hwnd == hCtrl || entry.txtCtrl.Hwnd == hCtrl) {
                        subHovered := entry
                        break
                    }
                }
            }
        }

        if (subHovered != "") {
            this._SetHover(this.Sub.lastHovered, false)
            this._SetHover(subHovered, true)
            this.Sub.lastHovered := subHovered
            ; Clear main hover except parent
            if (this.lastHoveredEntry != "" && this.lastHoveredEntry != this.Sub.parentEntry) {
                this._SetHover(this.lastHoveredEntry, false)
                this.lastHoveredEntry := ""
            }
            return true
        }
        return false
    }

    static _CheckMainMenuHover(hCtrl) {
        hovered := ""
        if hCtrl {
            Loop this.items.Length {
                entry := this.items[A_Index]
                if entry.isSep
                    continue

                try {
                    if (entry.bgCtrl.Hwnd == hCtrl || entry.txtCtrl.Hwnd == hCtrl) {
                        hovered := entry
                        break
                    }
                }
            }
        }
        if (hovered == "")
            return false

        ; Clear sub‑menu hover if any
        if (this.Sub.lastHovered != "") {
            this._SetHover(this.Sub.lastHovered, false)
            this.Sub.lastHovered := ""
        }

        if (hovered != this.lastHoveredEntry) {
            this._SetHover(this.lastHoveredEntry, false)
            this._SetHover(hovered, true)
            this.lastHoveredEntry := hovered
        }

        ; Show sub‑menu if entry has children
        if hovered.HasProp("children") {
            if (this.Sub.parentEntry != hovered) {
                this._HideSubMenu()
                this._ShowSubMenu(hovered)
            }
        } else {
            if (this.Sub.gui != "")
                this._HideSubMenu()
        }

        return true
    }

    static _SetHover(entry, isHover) {
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

    static _InvokeAndClose(cb, *) {
        this.Hide()
        if IsObject(cb)
            cb.Call()
    }

    static _InvokeSubAndClose(cb, *) {
        this._HideSubMenu()
        this.Hide()
        if IsObject(cb)
            cb.Call()
    }

    static _CheckOutsideClick() {
        hasMain := IsObject(this.menuGui) && WinExist("ahk_id " this.menuHwnd)
        hasSub := this.Sub.gui != "" && WinExist("ahk_id " this.Sub.hwnd)
        if (!hasMain && !hasSub) {
            if (this.outsideTimer != "")
                SetTimer(this.outsideTimer, 0)
            return
        }

        if !GetKeyState("LButton", "P")
            return

        MouseGetPos(&mx, &my)
        insideMain := this._IsPointInsideWindow(this.menuHwnd, mx, my)
        insideSub := this._IsPointInsideWindow(this.Sub.hwnd, mx, my)
        if (!insideMain && !insideSub)
            this.Hide()
    }

    static _IsPointInsideWindow(hwnd, mx, my) {
        if !hwnd
            return false

        try {
            WinGetPos(&wx, &wy, &ww, &wh, "ahk_id " hwnd)
            return (mx >= wx && mx <= wx + ww && my >= wy && my <= wy + wh)
        } catch {
            return false
        }
    }
}
