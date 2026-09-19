#Requires AutoHotkey v2.0

class CustomMenu {
    static menuGui := ""
    static menuHwnd := 0
    static items := []
    static lastHoveredEntry := ""
    static outsideTimer := ""
    static outsideSurfaceSince := 0
    static outsideDismissDelay := 240
    static interactionPadding := 10
    static mouseMoveHandler := ""
    static mouseMoveRegistered := false
    static controlEntries := Map()
    static WM_MOUSEMOVE := 0x0200

    ; Top-level tray menus need a short opening grace period because the
    ; pointer is still over the tray anchor when the custom menu appears.
    static menuOpenGraceUntil := 0
    static menuAnchorX := ""
    static menuAnchorY := ""
    static menuAnchorRadius := 24
    static itemH := 34
    static sepH := 9
    static menuW := 420
    static topPad := 16
    static subMenuGap := 1

    ; Sub-menu support
    static subMenuGui := ""
    static subMenuHwnd := 0
    static subMenuItems := []
    static subMenuLastHoveredEntry := ""
    static subMenuParentEntry := ""
    static subMenuGraceUntil := 0

    ; One additional submenu level is supported for grouped tray settings.
    ; This keeps the renderer reusable while preventing unbounded recursive
    ; popup windows and hover-state complexity.
    static nestedSubMenuGui := ""
    static nestedSubMenuHwnd := 0
    static nestedSubMenuItems := []
    static nestedSubMenuLastHoveredEntry := ""
    static nestedSubMenuParentEntry := ""
    static nestedSubMenuGraceUntil := 0

    ; Given screen coordinates (x, y), returns the monitor index (1-based)
    ; whose bounding rectangle contains the point. Falls back to the primary
    ; monitor if no match is found.
    static FindMonitorIndex(x, y) {
        Loop MonitorGetCount() {
            MonitorGet(A_Index, &mL, &mT, &mR, &mB)
            if x >= mL && x < mR && y >= mT && y < mB
                return A_Index
        }
        return MonitorGetPrimary()
    }

    ; ShowWithItems accepts an optional anchorBottom flag.
    ; When true, the menu's bottom-left corner aligns with (x, y).
    static ShowWithItems(x, y, itemsArray, anchorBottom := false) {
        this.Hide()
        this.items := this.NormalizeItems(itemsArray)
        this.lastHoveredEntry := ""
        this.outsideSurfaceSince := 0

        if anchorBottom {
            ; Preserve the original tray click point. BuildAndShow may shift
            ; Y upward for bottom anchoring, but the pointer remains at this
            ; original point while the menu is being opened.
            this.menuAnchorX := x
            this.menuAnchorY := y
        }

        this.BuildAndShow(x, y, anchorBottom)
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
            hasChildren := entry.HasProp("children") && IsObject(entry.children) && entry.children.Length > 0

            displayLabel := hasChildren ? this.ClipLabel(label, 46) . "  ▶" : this.ClipLabel(label, 52)

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

    ; Calculate the total menu height without building the GUI.
    ; Used to pre-compute offset for bottom-anchored menus.
    static CalcTotalHeight() {
        itemH := this.itemH
        sepH := this.sepH
        topPad := this.topPad

        totalH := topPad
        for entry in this.items
            totalH += entry.isSep ? sepH : itemH

        maxAllowed := A_ScreenHeight * 0.75
        if totalH > maxAllowed {
            ratio := maxAllowed / totalH
            itemH := Max(Integer(itemH * ratio), 22)
            sepH := Max(Integer(sepH * ratio), 4)
            topPad := Max(Integer(topPad * ratio), 6)
            totalH := topPad
            for entry in this.items
                totalH += entry.isSep ? sepH : itemH
        }

        return totalH
    }

    ; Calculate the DPI scaling factor for the screen.
    ; Returns the ratio of current DPI to the baseline 96 DPI (100%).
    ; At 125% DPI (120 dpi): returns 1.25
    ; At 150% DPI (144 dpi): returns 1.50
    static GetDpiScale() {
        return Max(A_ScreenDPI, 96) / 96.0
    }

    ; Clamp a proposed window position to a monitor's working area.
    ; If a window is larger than the available area, use the nearest origin
    ; rather than producing an invalid reversed clamp range.
    static ClampWindowPosition(x, y, width, height, waLeft, waTop, waRight, waBottom, margin := 5) {
        minX := waLeft + margin
        minY := waTop + margin
        maxX := waRight - width - margin
        maxY := waBottom - height - margin

        safeX := maxX < minX ? minX : Clamp(x, minX, maxX)
        safeY := maxY < minY ? minY : Clamp(y, minY, maxY)

        return { x: safeX, y: safeY }
    }

    ; Re-check the actual native window rectangle after Show().
    ; This compensates for non-client borders and per-monitor DPI rounding.
    static RepositionShownWindow(hwnd, monIdx) {
        if !hwnd || !WinExist("ahk_id " hwnd)
            return

        try {
            WinGetPos(&actualX, &actualY, &actualW, &actualH, "ahk_id " hwnd)
            MonitorGetWorkArea(monIdx, &waLeft, &waTop, &waRight, &waBottom)
            pos := this.ClampWindowPosition(actualX, actualY, actualW, actualH, waLeft, waTop, waRight, waBottom)

            if pos.x != actualX || pos.y != actualY
                WinMove(pos.x, pos.y, , , "ahk_id " hwnd)
        } catch {
            ; Positioning is best-effort; the menu itself remains functional.
        }
    }

    ; Calculate the vertical offset needed to align the menu's bottom-left
    ; corner with a tray icon click position.
    ;
    ; The offset compensates for:
    ;   - Taskbar height (varies, typically 40-48 px at 100% DPI)
    ;   - Tray icon vertical center offset (~12 px at 100% DPI)
    ;   - Window non-client frame border (~8 px at 100% DPI)
    ;
    ; All of the above scale proportionally with the DPI setting,
    ; so we compute a baseline at 96 DPI and multiply by the scale factor.
    ;
    ; Baseline values (empirically calibrated at 100% DPI / 96 dpi):
    ;   BASE_TASKBAR   = 40  — typical single-row taskbar height
    ;   BASE_ICON      = 12  — tray icon center-to-bottom offset
    ;   BASE_FRAME     = 8   — +Border +ToolWindow non-client frame
    ;   TOTAL BASE     = 60  — sum of the above
    static GetAnchorOffset() {
        static BASE_OFFSET := 60  ; calibrated at 96 DPI (100% scaling)
        return Round(BASE_OFFSET * this.GetDpiScale())
    }

    static BuildAndShow(x, y, anchorBottom := false) {
        if this.items.Length == 0
            return

        itemH := this.itemH
        sepH := this.sepH
        topPad := this.topPad

        totalH := topPad
        for entry in this.items
            totalH += entry.isSep ? sepH : itemH

        maxAllowed := A_ScreenHeight * 0.75
        if totalH > maxAllowed {
            ratio := maxAllowed / totalH
            itemH := Max(Integer(itemH * ratio), 22)
            sepH := Max(Integer(sepH * ratio), 4)
            topPad := Max(Integer(topPad * ratio), 6)
            totalH := topPad
            for entry in this.items
                totalH += entry.isSep ? sepH : itemH
        }

        menuW := this.menuW
        menuH := totalH

        myGui := Gui("+AlwaysOnTop -Caption +ToolWindow +Border")
        myGui.BackColor := AppState.THEME_SURFACE
        myGui.SetFont("s10 c" AppState.THEME_FG, AppState.THEME_FONT)

        curY := topPad // 2
        for entry in this.items {
            if entry.isSep {
                myGui.Add(
                    "Text",
                    "x12 y" (curY + 3) " w" (menuW - 24) " h1 Background" AppState.THEME_BORDER
                )
                curY += sepH
                continue
            }

            bgCtrl := myGui.Add(
                "Text",
                "x4 y" curY " w" (menuW - 8) " h" itemH " +0x0100 Background" AppState.THEME_SURFACE
            )

            txtCtrl := myGui.Add(
                "Text",
                "x16 y" (curY + (itemH - 20) // 2) " w" (menuW - 40) " h20 +0x0100 Background" AppState.THEME_SURFACE,
                entry.label
            )

            entry.bgCtrl := bgCtrl
            entry.txtCtrl := txtCtrl
            this.RegisterControlHit(bgCtrl, entry, "main")
            this.RegisterControlHit(txtCtrl, entry, "main")

            ; Parent rows are hover targets; clicking them should not toggle
            ; an already-open submenu closed.
            if entry.HasProp("children") {
                curY += itemH
                continue
            }

            if entry.HasProp("callback") && IsObject(entry.callback) {
                cb := ObjBindMethod(this, "InvokeAndClose", entry.callback)
                bgCtrl.OnEvent("Click", cb)
                txtCtrl.OnEvent("Click", cb)
            }

            curY += itemH
        }

        ; Resolve the monitor from the original tray click before changing
        ; the Y coordinate for bottom anchoring. This prevents a vertically
        ; stacked multi-monitor layout from selecting the wrong monitor.
        monIdx := this.FindMonitorIndex(x, y)
        MonitorGetWorkArea(monIdx, &waLeft, &waTop, &waRight, &waBottom)

        if anchorBottom {
            ; Shift Y up so the menu's bottom-left corner aligns with the
            ; tray icon click position. The offset is dynamically computed
            ; based on the current DPI scaling factor to adapt to different
            ; display resolutions and scaling settings.
            offset := this.GetAnchorOffset()
            y := y - menuH - offset
        }

        pos := this.ClampWindowPosition(x, y, menuW, menuH, waLeft, waTop, waRight, waBottom)
        posX := pos.x
        posY := pos.y

        this.menuGui := myGui
        this.menuHwnd := myGui.Hwnd

        if this.mouseMoveHandler == ""
            this.mouseMoveHandler := ObjBindMethod(this, "HandleMouseMove")
        if !this.mouseMoveRegistered {
            OnMessage(this.WM_MOUSEMOVE, this.mouseMoveHandler)
            this.mouseMoveRegistered := true
        }

        if this.outsideTimer == ""
            this.outsideTimer := ObjBindMethod(this, "CheckOutsideSurface")

        ThemeHelper.ApplyImmersiveDarkMode(this.menuHwnd)
        myGui.Show("x" posX " y" posY " w" menuW " h" menuH " NoActivate")
        this.RepositionShownWindow(this.menuHwnd, monIdx)

        ; Protect the short tray-to-menu transition. Hover handling itself is
        ; now message-driven and no longer waits for a timer tick.
        if anchorBottom
            this.menuOpenGraceUntil := A_TickCount + 1200
        else
            this.menuOpenGraceUntil := 0

        ; Keep only a lightweight watchdog for leaving the menu surface.
        SetTimer(this.outsideTimer, 75)
    }

    static RegisterControlHit(ctrl, entry, level) {
        if !IsObject(ctrl) || !IsObject(entry)
            return

        this.controlEntries[ctrl.Hwnd] := {
            entry: entry,
            level: level
        }
    }

    static UnregisterControlHits(itemsArray) {
        if !IsObject(itemsArray)
            return

        for entry in itemsArray {
            if !IsObject(entry) || (entry.HasProp("isSep") && entry.isSep)
                continue

            try {
                if entry.HasProp("bgCtrl")
                    this.controlEntries.Delete(entry.bgCtrl.Hwnd)
            }

            try {
                if entry.HasProp("txtCtrl")
                    this.controlEntries.Delete(entry.txtCtrl.Hwnd)
            }
        }
    }

    static HandleMouseMove(wParam, lParam, msg, hWnd) {
        if !this.mouseMoveRegistered || !IsObject(this.menuGui) || !hWnd
            return

        if !this.controlEntries.Has(hWnd)
            return

        hit := this.controlEntries[hWnd]
        if !IsObject(hit) || !hit.HasProp("entry")
            return

        entry := hit.entry

        if hit.level == "nested" {
            this.HandleNestedHover(entry)
        } else if hit.level == "sub" {
            this.HandleSubHover(entry)
        } else {
            this.HandleMainHover(entry)
        }
    }

    static HandleMainHover(entry) {
        if !IsObject(entry) || entry.isSep
            return

        if entry != this.lastHoveredEntry {
            this.SetHover(this.lastHoveredEntry, false)
            this.lastHoveredEntry := entry
            this.SetHover(entry, true)
        }

        if entry.HasProp("children") {
            if this.subMenuParentEntry != entry {
                this.HideSubMenu()
                this.lastHoveredEntry := entry
                this.SetHover(entry, true)
                this.ShowSubMenu(entry)
            }
        } else if this.subMenuGui != "" {
            this.HideSubMenu()
        }
    }

    static HandleSubHover(entry) {
        if !IsObject(entry) || entry.isSep
            return

        if entry != this.subMenuLastHoveredEntry {
            this.SetHover(this.subMenuLastHoveredEntry, false)
            this.SetHover(entry, true)
            this.subMenuLastHoveredEntry := entry
        }

        if entry.HasProp("children") {
            if this.nestedSubMenuParentEntry != entry {
                this.HideNestedSubMenu()
                this.ShowNestedSubMenu(entry)
            }
        } else if this.nestedSubMenuGui != "" {
            this.HideNestedSubMenu()
        }
    }

    static HandleNestedHover(entry) {
        if !IsObject(entry) || entry.isSep
            return

        if entry != this.nestedSubMenuLastHoveredEntry {
            this.SetHover(this.nestedSubMenuLastHoveredEntry, false)
            this.SetHover(entry, true)
            this.nestedSubMenuLastHoveredEntry := entry
        }
    }

    static ToggleSubMenu(entry, *) {
        if this.subMenuParentEntry == entry && this.subMenuGui != "" {
            this.HideSubMenu()
        } else {
            this.HideSubMenu()
            this.ShowSubMenu(entry)
        }
    }

    ; Sub-menu expands upward by default: its bottom edge aligns with
    ; the bottom edge of the parent entry. Falls back to downward expansion
    ; only if upward would push the menu off the top of the screen.
    static ShowSubMenu(parentEntry) {
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

        subItemH := this.itemH + 4
        subSepH := this.sepH
        subTopPad := 16
        subBottomPad := 10
        subMenuW := 380

        subTotalH := subTopPad + subBottomPad
        for entry in subItems
            subTotalH += entry.isSep ? subSepH : subItemH

        subMyGui := Gui("+AlwaysOnTop -Caption +ToolWindow +Border")
        subMyGui.BackColor := AppState.THEME_SURFACE
        subMyGui.SetFont("s10 c" AppState.THEME_FG, AppState.THEME_FONT)

        subCurY := subTopPad // 2
        for entry in subItems {
            if entry.isSep {
                subMyGui.Add(
                    "Text",
                    "x12 y" (subCurY + 3) " w" (subMenuW - 24) " h1 Background" AppState.THEME_BORDER
                )
                subCurY += subSepH
                continue
            }

            bgCtrl := subMyGui.Add(
                "Text",
                "x4 y" subCurY " w" (subMenuW - 8) " h" subItemH " +0x0100 Background" AppState.THEME_SURFACE
            )

            txtCtrl := subMyGui.Add(
                "Text",
                "x16 y" (subCurY + (subItemH - 20) // 2) " w" (subMenuW - 40) " h20 +0x0100 Background" AppState.THEME_SURFACE,
                entry.label
            )

            entry.bgCtrl := bgCtrl
            entry.txtCtrl := txtCtrl
            this.RegisterControlHit(bgCtrl, entry, "sub")
            this.RegisterControlHit(txtCtrl, entry, "sub")

            if entry.HasProp("children") {
                ; Nested submenus are opened by pointer hover.
                subCurY += subItemH
                continue
            }

            if entry.HasProp("callback") && IsObject(entry.callback) {
                cb := ObjBindMethod(this, "InvokeSubAndClose", entry.callback)
                bgCtrl.OnEvent("Click", cb)
                txtCtrl.OnEvent("Click", cb)
            }

            subCurY += subItemH
        }

        ; Position the submenu directly beside the hovered parent row.
        ; Align the top edge with the parent row so the pointer can move
        ; horizontally into the submenu instead of crossing a large vertical gap.
        subX := px + pw + this.subMenuGap
        subY := py

        ; Resolve the working area from the parent entry's monitor so the
        ; position remains stable when the submenu is flipped horizontally.
        monIdx := this.FindMonitorIndex(px + pw // 2, py + ph // 2)
        MonitorGetWorkArea(monIdx, &waLeft, &waTop, &waRight, &waBottom)

        ; Flip horizontally when there is not enough room on the right.
        if subX + subMenuW > waRight - 5
            subX := px - subMenuW - this.subMenuGap

        ; Keep the predicted submenu rectangle inside the monitor work area.
        subPos := this.ClampWindowPosition(subX, subY, subMenuW, subTotalH, waLeft, waTop, waRight, waBottom)
        subX := subPos.x
        subY := subPos.y

        this.subMenuGui := subMyGui
        this.subMenuHwnd := subMyGui.Hwnd
        this.subMenuItems := subItems
        this.subMenuLastHoveredEntry := ""
        this.subMenuParentEntry := parentEntry
        this.subMenuGraceUntil := A_TickCount + 350

        ; Keep parent entry highlighted while sub-menu is open
        this.SetHover(parentEntry, true)

        ThemeHelper.ApplyImmersiveDarkMode(this.subMenuHwnd)
        subMyGui.Show("x" subX " y" subY " w" subMenuW " h" subTotalH " NoActivate")
        this.RepositionShownWindow(this.subMenuHwnd, monIdx)
    }

    static NormalizeSubItems(itemsArray) {
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
            hasChildren := entry.HasProp("children")
                && IsObject(entry.children)
                && entry.children.Length > 0

            displayLabel := hasChildren
                ? this.ClipLabel(label, 42) . "  ▶"
                : this.ClipLabel(label, 44)

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

    static ToggleNestedSubMenu(entry, *) {
        if this.nestedSubMenuParentEntry == entry && this.nestedSubMenuGui != "" {
            this.HideNestedSubMenu()
        } else {
            this.HideNestedSubMenu()
            this.ShowNestedSubMenu(entry)
        }
    }

    static ShowNestedSubMenu(parentEntry) {
        if !parentEntry.HasProp("children")
            return

        children := parentEntry.children
        if !IsObject(children) || children.Length == 0
            return

        ; The parent entry belongs to the first submenu, so resolve its
        ; screen position against that submenu's window rather than the main
        ; tray menu.
        try {
            parentEntry.bgCtrl.GetPos(&px, &py, &pw, &ph)
            WinGetPos(&wx, &wy, , , "ahk_id " this.subMenuHwnd)
            px += wx
            py += wy
        } catch {
            return
        }

        nestedItems := this.NormalizeSubItems(children)
        if nestedItems.Length == 0
            return

        nestedItemH := this.itemH + 4
        nestedSepH := this.sepH
        nestedTopPad := 16
        nestedBottomPad := 10
        nestedMenuW := 380

        nestedTotalH := nestedTopPad + nestedBottomPad
        for entry in nestedItems
            nestedTotalH += entry.isSep ? nestedSepH : nestedItemH

        nestedGui := Gui("+AlwaysOnTop -Caption +ToolWindow +Border")
        nestedGui.BackColor := AppState.THEME_SURFACE
        nestedGui.SetFont("s10 c" AppState.THEME_FG, AppState.THEME_FONT)

        curY := nestedTopPad // 2
        for entry in nestedItems {
            if entry.isSep {
                nestedGui.Add(
                    "Text",
                    "x12 y" (curY + 3) " w" (nestedMenuW - 24) " h1 Background" AppState.THEME_BORDER
                )
                curY += nestedSepH
                continue
            }

            bgCtrl := nestedGui.Add(
                "Text",
                "x4 y" curY " w" (nestedMenuW - 8) " h" nestedItemH " +0x0100 Background" AppState.THEME_SURFACE
            )

            txtCtrl := nestedGui.Add(
                "Text",
                "x16 y" (curY + (nestedItemH - 20) // 2)
                    " w" (nestedMenuW - 40)
                    " h20 +0x0100 Background" AppState.THEME_SURFACE,
                entry.label
            )

            entry.bgCtrl := bgCtrl
            entry.txtCtrl := txtCtrl
            this.RegisterControlHit(bgCtrl, entry, "nested")
            this.RegisterControlHit(txtCtrl, entry, "nested")

            if entry.HasProp("children") {
                curY += nestedItemH
                continue
            }

            if entry.HasProp("callback") && IsObject(entry.callback) {
                cb := ObjBindMethod(this, "InvokeSubAndClose", entry.callback)
                bgCtrl.OnEvent("Click", cb)
                txtCtrl.OnEvent("Click", cb)
            }

            curY += nestedItemH
        }

        nestedX := px + pw + this.subMenuGap
        nestedY := py

        monIdx := this.FindMonitorIndex(px + pw // 2, py + ph // 2)
        MonitorGetWorkArea(monIdx, &waLeft, &waTop, &waRight, &waBottom)

        if nestedX + nestedMenuW > waRight - 5
            nestedX := px - nestedMenuW - this.subMenuGap

        nestedPos := this.ClampWindowPosition(
            nestedX,
            nestedY,
            nestedMenuW,
            nestedTotalH,
            waLeft,
            waTop,
            waRight,
            waBottom
        )
        nestedX := nestedPos.x
        nestedY := nestedPos.y

        this.nestedSubMenuGui := nestedGui
        this.nestedSubMenuHwnd := nestedGui.Hwnd
        this.nestedSubMenuItems := nestedItems
        this.nestedSubMenuLastHoveredEntry := ""
        this.nestedSubMenuParentEntry := parentEntry
        this.nestedSubMenuGraceUntil := A_TickCount + 350

        this.SetHover(parentEntry, true)

        ThemeHelper.ApplyImmersiveDarkMode(this.nestedSubMenuHwnd)
        nestedGui.Show(
            "x" nestedX " y" nestedY
            " w" nestedMenuW " h" nestedTotalH " NoActivate"
        )
        this.RepositionShownWindow(this.nestedSubMenuHwnd, monIdx)
    }

    static HideNestedSubMenu() {
        if this.nestedSubMenuGui == ""
            return

        if this.nestedSubMenuParentEntry != "" && IsObject(this.nestedSubMenuParentEntry)
            this.SetHover(this.nestedSubMenuParentEntry, false)

        this.UnregisterControlHits(this.nestedSubMenuItems)

        try this.nestedSubMenuGui.Destroy()
        this.nestedSubMenuGui := ""
        this.nestedSubMenuHwnd := 0
        this.nestedSubMenuItems := []
        this.nestedSubMenuLastHoveredEntry := ""
        this.nestedSubMenuParentEntry := ""
        this.nestedSubMenuGraceUntil := 0
    }

    static HideSubMenu() {
        this.HideNestedSubMenu()

        if this.subMenuGui != "" {
            ; Restore parent entry normal state.
            if this.subMenuParentEntry != "" && IsObject(this.subMenuParentEntry)
                this.SetHover(this.subMenuParentEntry, false)

            this.UnregisterControlHits(this.subMenuItems)

            try this.subMenuGui.Destroy()
            this.subMenuGui := ""
            this.subMenuHwnd := 0
            this.subMenuItems := []
            this.subMenuLastHoveredEntry := ""
            this.subMenuParentEntry := ""
            this.subMenuGraceUntil := 0
        }
    }

    static IsPointInWindow(hwnd, x, y, padding := 0) {
        if !hwnd || !WinExist("ahk_id " hwnd)
            return false

        try {
            WinGetPos(&wx, &wy, &ww, &wh, "ahk_id " hwnd)
            return x >= wx - padding && x <= wx + ww + padding
                && y >= wy - padding && y <= wy + wh + padding
        } catch {
            return false
        }
    }

    static IsPointInWindowBridge(hwndA, hwndB, x, y, padding := 10) {
        if !hwndA || !hwndB
            return false
        if !WinExist("ahk_id " hwndA) || !WinExist("ahk_id " hwndB)
            return false

        try {
            WinGetPos(&ax, &ay, &aw, &ah, "ahk_id " hwndA)
            WinGetPos(&bx, &by, &bw, &bh, "ahk_id " hwndB)

            left := Min(ax, bx) - padding
            top := Min(ay, by) - padding
            right := Max(ax + aw, bx + bw) + padding
            bottom := Max(ay + ah, by + bh) + padding

            return x >= left && x <= right && y >= top && y <= bottom
        } catch {
            return false
        }
    }

    static IsPointInInteractionSurface(x, y) {
        if this.menuAnchorX != "" && this.menuAnchorY != ""
            && Abs(x - this.menuAnchorX) <= this.menuAnchorRadius
            && Abs(y - this.menuAnchorY) <= this.menuAnchorRadius
            return true

        padding := this.interactionPadding

        if this.IsPointInWindow(this.menuHwnd, x, y, padding)
            return true
        if this.IsPointInWindow(this.subMenuHwnd, x, y, padding)
            return true
        if this.IsPointInWindow(this.nestedSubMenuHwnd, x, y, padding)
            return true

        if this.subMenuHwnd
            && this.IsPointInWindowBridge(this.menuHwnd, this.subMenuHwnd, x, y, padding)
            return true

        if this.nestedSubMenuHwnd
            && this.IsPointInWindowBridge(this.subMenuHwnd, this.nestedSubMenuHwnd, x, y, padding)
            return true

        return false
    }

    static CheckOutsideSurface() {
        if !IsObject(this.menuGui)
            return

        hasMain := this.menuHwnd && WinExist("ahk_id " this.menuHwnd)
        hasSub := this.subMenuHwnd && WinExist("ahk_id " this.subMenuHwnd)
        hasNested := this.nestedSubMenuHwnd && WinExist("ahk_id " this.nestedSubMenuHwnd)

        if !hasMain && !hasSub && !hasNested {
            if this.outsideTimer != ""
                SetTimer(this.outsideTimer, 0)
            this.outsideSurfaceSince := 0
            return
        }

        MouseGetPos(&mx, &my)
        now := A_TickCount

        if this.IsPointInInteractionSurface(mx, my) {
            this.outsideSurfaceSince := 0
            return
        }

        graceUntil := Max(
            this.menuOpenGraceUntil,
            this.subMenuGraceUntil,
            this.nestedSubMenuGraceUntil
        )

        if now < graceUntil {
            this.outsideSurfaceSince := 0
            return
        }

        if GetKeyState("LButton", "P")
            || GetKeyState("RButton", "P")
            || GetKeyState("MButton", "P") {
            this.outsideSurfaceSince := 0
            this.Hide()
            return
        }

        if !this.outsideSurfaceSince
            this.outsideSurfaceSince := now

        if now - this.outsideSurfaceSince < this.outsideDismissDelay
            return

        this.outsideSurfaceSince := 0
        this.Hide()
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

    static InvokeSubAndClose(cb, *) {
        this.HideSubMenu()
        this.Hide()
        if IsObject(cb)
            cb.Call()
    }

    static Hide() {
        this.HideSubMenu()

        if this.mouseMoveRegistered {
            OnMessage(this.WM_MOUSEMOVE, this.mouseMoveHandler, 0)
            this.mouseMoveRegistered := false
        }

        if this.outsideTimer != ""
            SetTimer(this.outsideTimer, 0)

        this.UnregisterControlHits(this.items)

        if IsObject(this.menuGui) {
            try this.menuGui.Destroy()
        }

        this.menuGui := ""
        this.menuHwnd := 0
        this.items := []
        this.controlEntries := Map()
        this.lastHoveredEntry := ""
        this.menuOpenGraceUntil := 0
        this.menuAnchorX := ""
        this.menuAnchorY := ""
        this.outsideSurfaceSince := 0
    }

    ; ClipLabel truncates text to fit within maxUnits display width units.
    ; ASCII characters count as 1 unit, non-ASCII (CJK, emoji, etc.) count as 2 units.
    ;
    ; Optimized with fast-path for short ASCII text (most common case in menus).
    static ClipLabel(text, maxUnits := 46) {
        text := RegExReplace(String(text), "\s+", " ")
        text := Trim(text)
        if text == ""
            text := "(empty)"

        ; Fast path: short strings (<= half maxUnits) won't need truncation
        ; even if they were all non-ASCII, so return immediately
        if StrLen(text) <= maxUnits // 2 {
            return StrReplace(text, "&", "&&")
        }

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

        ; If loop completed without truncation, out will equal original text
        if out == ""
            return StrReplace(text, "&", "&&")

        return StrReplace(out, "&", "&&")
    }
}
