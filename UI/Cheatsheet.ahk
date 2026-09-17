#Requires AutoHotkey v2.0

; ---------------------------------------------------------------------------
; Built-in hotkey reference (cheatsheet).
;
; CapsLock + H toggles the overlay, Esc or a second CapsLock + H closes it.
; The rows come from Hotkeys\HotkeyReference.ahk (single source of truth),
; the list is searchable, rows with an attached action can be launched with
; a double-click, and every string goes through the language resources.
; ---------------------------------------------------------------------------
class HotkeyReferenceGui {
    static gui        := ""
    static listView   := ""
    static searchBox  := ""
    static statusBar  := ""
    static rows       := []
    static visible    := []

    ; --- Layout constants (kept in sync with History\FullHistoryGui.ahk) ---
    static MARGIN        := 16
    static TITLE_AREA_H  := 56
    static SEPARATOR_H   := 2
    static SEARCH_AREA_H := 34
    static STATUS_H      := 28
    static GAP           := 10

    static Toggle() {
        if IsObject(this.gui) {
            try {
                if WinExist("ahk_id " this.gui.Hwnd) {
                    this.Close()
                    return
                }
            } catch {
            }
            this.Close()
        }

        this.Show()
    }

    static Show() {
        margin := this.MARGIN
        searchY := margin + this.TITLE_AREA_H + this.SEPARATOR_H + this.GAP
        lvY := searchY + this.SEARCH_AREA_H + this.GAP

        myGui := Gui("+Resize +AlwaysOnTop +DPIScale +MinSize620x360", Lang("CHEAT_TITLE"))
        ThemeHelper.StyleGui(myGui)
        myGui.OnEvent("Close", (*) => HotkeyReferenceGui.Close())
        myGui.OnEvent("Escape", (*) => HotkeyReferenceGui.Close())
        myGui.OnEvent("Size", (g, minmax, w, h) => HotkeyReferenceGui.Resize(g, w, h))

        ThemeHelper.AddTitle(myGui, "⌨️ " Lang("CHEAT_TITLE"), 640)
        ThemeHelper.AddSubtitle(myGui, Lang("CHEAT_HINT"), 640)
        ThemeHelper.AddSeparator(myGui, 640)

        myGui.SetFont("s10 c" AppState.THEME_FG_MUTED, AppState.THEME_FONT)
        searchIcon := myGui.Add("Text", "x" margin " y" searchY, "🔍")
        myGui.SetFont("s10 c" AppState.THEME_FG, AppState.THEME_FONT)
        search := myGui.Add(
            "Edit",
            "x" (margin + 22) " y" (searchY - 2) " w560 " ThemeHelper.GetEditOptions("r1")
        )
        search.OnEvent("Change", (*) => HotkeyReferenceGui.Refresh())

        lv := myGui.Add(
            "ListView",
            "x" margin " y" lvY " r16 w640 Grid " ThemeHelper.GetLVOptions(),
            [Lang("CHEAT_COL_CATEGORY"), Lang("CHEAT_COL_SHORTCUT"), Lang("CHEAT_COL_ACTION")]
        )
        lv.ModifyCol(1, 110)
        lv.ModifyCol(2, 190)
        lv.ModifyCol(3, 320)
        lv.OnEvent("DoubleClick", (lvObj, row) => HotkeyReferenceGui.RunEntry(row))
        ThemeHelper.StyleListView(lv)

        myGui.SetFont("s8 c" AppState.THEME_FG_MUTED, AppState.THEME_FONT)
        status := myGui.Add("Text", "x" margin " y+10 w640", "")
        myGui.SetFont("s10 c" AppState.THEME_FG, AppState.THEME_FONT)

        this.gui := myGui
        this.listView := lv
        this.searchBox := search
        this.statusBar := status
        this.searchIcon := searchIcon

        myGui.Show("w672 h560")
        ThemeHelper.ApplyImmersiveDarkMode(myGui.Hwnd)
        this.Refresh()
    }

    static Refresh() {
        lv := this.listView
        if !IsObject(lv)
            return

        ; Localized rows are built once per opening so the overlay always
        ; reflects the language that is active at that moment.
        if this.rows.Length == 0 {
            for entry in HotkeyReference.Entries() {
                this.rows.Push({
                    cat: Lang(entry.cat),
                    keys: entry.keys,
                    desc: Lang(entry.desc),
                    action: entry.action
                })
            }
        }

        filter := ""
        try filter := StrLower(Trim(this.searchBox.Text))
        catch
            filter := ""

        this.visible := []

        SendMessage(0x000B, 0, 0, lv.Hwnd)
        lv.Delete()

        for row in this.rows {
            if filter != "" && !InStr(StrLower(row.cat " " row.keys " " row.desc), filter)
                continue

            this.visible.Push(row)
            lv.Add(, row.cat, row.keys, row.desc)
        }

        SendMessage(0x000B, 1, 0, lv.Hwnd)

        if IsObject(this.statusBar)
            this.statusBar.Text := Lang("CHEAT_STATUS", "", this.visible.Length, this.rows.Length)
    }

    ; Double-click: close the overlay first, then run the action so the
    ; target window is the one that was active before the cheatsheet.
    static RunEntry(row) {
        if row == 0 || row > this.visible.Length
            return

        entry := this.visible[row]

        if !IsObject(entry.action) {
            ShowToolTip(Lang("MSG_CHEAT_NO_ACTION"), 1500)
            return
        }

        action := entry.action
        this.Close()
        SetTimer(() => action.Call(), -150)
    }

    static Resize(g, w, h) {
        if !IsObject(g) || !IsObject(this.listView)
            return

        margin := this.MARGIN
        searchY := margin + this.TITLE_AREA_H + this.SEPARATOR_H + this.GAP
        lvY := searchY + this.SEARCH_AREA_H + this.GAP
        lvH := h - lvY - this.STATUS_H - this.GAP * 2
        if lvH < 120
            lvH := 120

        if IsObject(this.searchBox)
            this.searchBox.Move(margin + 22, searchY - 2, w - margin * 2 - 22)

        this.listView.Move(margin, lvY, w - margin * 2, lvH)

        if IsObject(this.statusBar)
            this.statusBar.Move(margin, lvY + lvH + this.GAP, w - margin * 2)
    }

    static Close() {
        if IsObject(this.gui)
            try this.gui.Destroy()

        this.gui := ""
        this.listView := ""
        this.searchBox := ""
        this.statusBar := ""
        this.rows := []
        this.visible := []
    }
}
