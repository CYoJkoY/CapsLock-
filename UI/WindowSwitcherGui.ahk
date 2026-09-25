#Requires AutoHotkey v2.0

; ---------------------------------------------------------------------------
; WindowSwitcherGui
;
; Searchable top-level window switcher (CapsLock + L).
;
; Presentation goals:
;   * application identity first: icon + friendly application name
;   * clear hierarchy: application -> window title -> process name
;   * a selected row that is obvious without relying on the system highlight
;   * keyboard-first: search, arrow keys, Enter, no animation
;
; Presentation settings live in AppState (persisted by ConfigManager) so the
; switcher can be tuned from the tray menu without touching the keyboard flow.
; ---------------------------------------------------------------------------

class WindowSwitcherGui {
    static Instance := ""
    static _imageList := 0
    static _notifyHooked := false
    static _dcBrush := 0

    ; --- Presentation helpers ---------------------------------------------

    static IconSize() {
        size := AppState.WindowSwitcherIconSize
        size := (size is Integer) ? size : 24
        return WindowIcons.ScaleForDpi(size)
    }

    ; Row density controls the list font and how many rows fit before the
    ; switcher starts scrolling.
    static DensityProfile(density := "") {
        if density == ""
            density := AppState.WindowSwitcherDensity

        switch StrLower(Trim(density)) {
            case "compact":
                return { font: "s9", rows: 16 }
            case "spacious":
                return { font: "s11", rows: 10 }
            default:
                return { font: "s10", rows: 13 }
        }
    }

    static ShowIcons() => AppState.WindowSwitcherShowIcons ? true : false

    static ShowProcessColumn() => AppState.WindowSwitcherShowProcess ? true : false

    ; --- GUI ---------------------------------------------------------------

    static Show() {
        this.Close()

        profile := this.DensityProfile()
        iconSize := this.IconSize()
        showProcess := this.ShowProcessColumn()

        myGui := Gui(
            "+AlwaysOnTop -MaximizeBox -MinimizeBox",
            Lang("GUI_WINDOW_SWITCHER_TITLE", "Window Switcher")
        )

        ThemeHelper.StyleGui(myGui)

        ThemeHelper.AddTitle(
            myGui,
            "▣ " Lang("GUI_WINDOW_SWITCHER_TITLE", "Window Switcher"),
            640
        )

        ThemeHelper.AddSubtitle(
            myGui,
            Lang(
                "GUI_WINDOW_SWITCHER_HINT",
                "Search by title or application. Press Enter or double-click to activate."
            ),
            640
        )

        ThemeHelper.AddSeparator(myGui, 640)

        search := myGui.Add(
            "Edit",
            "w640 r1 y+12 " ThemeHelper.GetEditOptions(),
            ""
        )
        ThemeHelper.StyleEdit(search)

        columns := [
            Lang("GUI_WINDOW_SWITCHER_COL_PROCESS", "Application"),
            Lang("GUI_WINDOW_SWITCHER_COL_TITLE", "Window")
        ]

        if showProcess
            columns.Push(Lang("GUI_WINDOW_SWITCHER_COL_EXE", "Process"))

        ; The list font is set for this control only, so the row height and
        ; text size follow the configured row density.
        myGui.SetFont(profile.font " c" AppState.THEME_FG, AppState.THEME_FONT)

        list := myGui.Add(
            "ListView",
            "w640 r" . profile.rows . " y+10 -Multi "
                . ThemeHelper.GetLVOptionsPlain(),
            columns
        )

        myGui.SetFont("s10 c" AppState.THEME_FG, AppState.THEME_FONT)

        ; Full-row selection keeps the highlight readable end to end; double
        ; buffering keeps filtering from flickering.
        this.ApplyListStyles(list)

        list.ModifyCol(1, 200)
        list.ModifyCol(2, showProcess ? 300 : 440)
        if showProcess
            list.ModifyCol(3, 140)

        ThemeHelper.StyleListView(list)

        ; The image list is attached even when icons are hidden: its size also
        ; defines the row height, so rows stay evenly spaced either way.
        this._imageList := WindowIcons.CreateImageList(iconSize)
        if this._imageList
            WindowIcons.AttachImageList(this._imageList, list.Hwnd)

        myGui.SetFont("s8 c" AppState.THEME_FG_DIM, AppState.THEME_FONT)
        status := myGui.Add(
            "Text",
            "w640 y+8",
            ""
        )
        myGui.SetFont("s10 c" AppState.THEME_FG, AppState.THEME_FONT)
        ThemeHelper.MarkDim(status)

        activateBtn := ThemeHelper.AddButton(
            myGui,
            "Default w110 y+12",
            "✓ " Lang("GUI_WINDOW_SWITCHER_ACTIVATE", "Activate"),
            "primary"
        )

        closeBtn := ThemeHelper.AddButton(
            myGui,
            "x+8 w90",
            "✕ " Lang("GUI_FULL_CLOSE", "Close")
        )

        myGui.SearchBox := search
        myGui.ListView := list
        myGui.Status := status
        myGui.VisibleWindows := []
        myGui.AllWindows := []
        myGui.IconIndex := Map()

        search.OnEvent(
            "Change",
            (*) => WindowSwitcherGui.Refresh(false)
        )

        list.OnEvent(
            "DoubleClick",
            (*) => WindowSwitcherGui.ActivateSelected()
        )

        list.OnEvent(
            "ItemSelect",
            (*) => WindowSwitcherGui.UpdateStatus()
        )

        activateBtn.OnEvent(
            "Click",
            (*) => WindowSwitcherGui.ActivateSelected()
        )

        closeBtn.OnEvent(
            "Click",
            (*) => WindowSwitcherGui.Close()
        )

        myGui.OnEvent(
            "Escape",
            (*) => WindowSwitcherGui.Close()
        )

        myGui.OnEvent(
            "Close",
            (*) => WindowSwitcherGui.Close()
        )

        this.Instance := myGui
        this.EnsureNotifyHook()

        ThemeHelper.ApplyImmersiveDarkMode(myGui.Hwnd)

        myGui.Show("AutoSize")

        this.Refresh(true)
        search.Focus()
    }

    ; Extended list styles are set through LVM_SETEXTENDEDLISTVIEWSTYLE so the
    ; flags are explicit and do not depend on option-string parsing.
    static ApplyListStyles(list) {
        static LVM_SETEXTENDEDLISTVIEWSTYLE := 0x1036
        static LVS_EX_FULLROWSELECT := 0x00000020
        static LVS_EX_DOUBLEBUFFER := 0x00010000

        styles := LVS_EX_FULLROWSELECT | LVS_EX_DOUBLEBUFFER

        try
            SendMessage(
                LVM_SETEXTENDEDLISTVIEWSTYLE,
                styles,
                styles,
                ,
                "ahk_id " list.Hwnd
            )
    }

    static Refresh(refreshWindows := true) {
        myGui := this.Instance

        if !IsObject(myGui) || !IsObject(myGui.ListView)
            return

        if refreshWindows || !myGui.HasProp("AllWindows")
            myGui.AllWindows := this.CollectWindows()

        filter := ""

        try
            filter := StrLower(Trim(myGui.SearchBox.Text))
        catch
            filter := ""

        lv := myGui.ListView
        windows := myGui.AllWindows
        visible := []
        iconSize := this.IconSize()
        showIcons := this.ShowIcons()
        showProcess := this.ShowProcessColumn()

        ; Redraw is suspended for the whole batch so filtering stays instant
        ; even with a long window list.
        try
            SendMessage(0x000B, 0, 0, , "ahk_id " lv.Hwnd)   ; WM_SETREDRAW

        lv.Delete()

        for entry in windows {
            label := entry.display != "" ? entry.display : entry.process
            haystack := StrLower(label " " entry.process " " entry.title)

            if filter != "" && !InStr(haystack, filter)
                continue

            visible.Push(entry)

            options := ""
            if showIcons && this._imageList {
                index := this.IconIndex(myGui, entry, iconSize)
                if index >= 0
                    options := "Icon" (index + 1)
            }

            if showProcess
                lv.Add(options, label, entry.title, entry.process)
            else
                lv.Add(options, label, entry.title)
        }

        myGui.VisibleWindows := visible

        try
            SendMessage(0x000B, 1, 0, , "ahk_id " lv.Hwnd)   ; WM_SETREDRAW
        try
            DllCall("user32\InvalidateRect", "Ptr", lv.Hwnd, "Ptr", 0, "Int", 1)

        if visible.Length > 0
            lv.Modify(1, "Select Focus")

        this.UpdateStatus()
    }

    ; Resolves (and caches) the image-list index for one window so repeated
    ; refreshes do not keep growing the image list.
    static IconIndex(myGui, entry, iconSize) {
        if !myGui.HasProp("IconIndex")
            myGui.IconIndex := Map()

        key := entry.hwnd

        if myGui.IconIndex.Has(key)
            return myGui.IconIndex[key]

        hIcon := WindowIcons.GetIconForWindow(entry.hwnd, entry.path, iconSize)
        if !hIcon
            return -1

        index := WindowIcons.AddIcon(this._imageList, hIcon)
        if index < 0
            return -1

        myGui.IconIndex[key] := index
        return index
    }

    static CollectWindows() {
        result := []
        processNames := Map()
        processPaths := Map()
        displayNames := Map()

        ownPid := DllCall(
            "GetCurrentProcessId",
            "UInt"
        )

        try {
            for hwnd in WinGetList() {
                if !hwnd || hwnd == A_ScriptHwnd
                    continue

                if !DllCall(
                    "IsWindowVisible",
                    "Ptr",
                    hwnd
                )
                    continue

                style := DllCall(
                    "GetWindowLongPtr",
                    "Ptr",
                    hwnd,
                    "Int",
                    -16,
                    "Ptr"
                )

                exStyle := DllCall(
                    "GetWindowLongPtr",
                    "Ptr",
                    hwnd,
                    "Int",
                    -20,
                    "Ptr"
                )

                ; WS_CHILD: do not expose controls or nested child windows.
                if style & 0x40000000
                    continue

                ; WS_EX_TOOLWINDOW: skip transient/tool windows.
                if exStyle & 0x00000080
                    continue

                ; WS_EX_NOACTIVATE: skip windows that cannot be normally activated.
                if exStyle & 0x08000000
                    continue

                pid := 0

                try
                    pid := WinGetPID("ahk_id " hwnd)
                catch
                    continue

                ; Exclude CapsLock-'s own GUI and transient windows.
                if pid == ownPid
                    continue

                className := ""

                try
                    className := WinGetClass("ahk_id " hwnd)
                catch
                    continue

                ; Exclude the desktop and shell surfaces.
                if (
                    className == "Progman"
                    || className == "WorkerW"
                    || className == "Shell_TrayWnd"
                    || className == "Shell_SecondaryTrayWnd"
                )
                    continue

                title := ""

                try
                    title := Trim(WinGetTitle("ahk_id " hwnd))
                catch
                    continue

                if title == ""
                    continue

                if processNames.Has(pid) {
                    processName := processNames[pid]
                    path := processPaths.Has(pid) ? processPaths[pid] : ""
                    display := displayNames.Has(pid) ? displayNames[pid] : ""
                } else {
                    processName := ""
                    try
                        processName := WinGetProcessName("ahk_id " hwnd)
                    catch
                        continue

                    if processName == ""
                        continue

                    path := ""
                    try
                        path := WinGetProcessPath("ahk_id " hwnd)
                    catch
                        path := ""

                    display := WindowIcons.GetDisplayName(path, processName)

                    processNames[pid] := processName
                    processPaths[pid] := path
                    displayNames[pid] := display
                }

                result.Push({
                    hwnd: hwnd,
                    pid: pid,
                    process: processName,
                    path: path,
                    display: display,
                    title: title
                })
            }
        } catch {
        }

        return result
    }

    static ActivateSelected() {
        myGui := this.Instance

        if !IsObject(myGui)
            return

        row := myGui.ListView.GetNext(
            0,
            "Focused"
        )

        if !row
            row := myGui.ListView.GetNext(0)

        if !row || row > myGui.VisibleWindows.Length
            return

        entry := myGui.VisibleWindows[row]
        hwnd := entry.hwnd

        if !WinExist("ahk_id " hwnd) {
            this.Refresh(true)
            return
        }

        this.Close()

        Sleep(30)

        try {
            if WinGetMinMax("ahk_id " hwnd) == -1
                WinRestore("ahk_id " hwnd)

            WinActivate("ahk_id " hwnd)

            if !WinWaitActive(
                "ahk_id " hwnd,
                ,
                1
            )
                throw Error(
                    "Selected window could not be activated."
                )
        } catch {
            ShowToolTip(
                Lang(
                    "MSG_WINDOW_ACTIVATE_FAILED",
                    "The selected window could not be activated."
                ),
                2000
            )
        }
    }

    ; Keyboard navigation used while the search box has focus.
    static MoveSelection(delta) {
        myGui := this.Instance

        if !IsObject(myGui) || !IsObject(myGui.ListView)
            return

        lv := myGui.ListView
        row := lv.GetNext(0, "Focused")

        if !row
            row := lv.GetNext(0)

        if !row
            row := 0

        row += delta

        if row < 1
            row := 1

        if row > lv.GetCount()
            row := lv.GetCount()

        if row < 1
            return

        lv.Modify(row, "Select Focus")

        try
            lv.Modify(row, "Vis")

        this.UpdateStatus()
    }

    static UpdateStatus() {
        myGui := this.Instance

        if !IsObject(myGui) || !myGui.HasProp("Status")
            return

        count := myGui.HasProp("VisibleWindows") ? myGui.VisibleWindows.Length : 0

        if count == 0 {
            myGui.Status.Text := Lang(
                "GUI_WINDOW_SWITCHER_EMPTY",
                "No matching windows found."
            )
            return
        }

        text := Lang(
            "GUI_WINDOW_SWITCHER_STATUS",
            "{1} window(s)",
            count
        )

        row := myGui.ListView.GetNext(0, "Focused")
        if !row
            row := myGui.ListView.GetNext(0)

        if row && row <= count {
            entry := myGui.VisibleWindows[row]
            detail := entry.display != "" ? entry.display : entry.process
            text .= "   ·   " detail
        }

        myGui.Status.Text := text
    }

    static Close() {
        if IsObject(this.Instance) {
            try
                this.Instance.Destroy()
        }

        ; The list must be gone before its image list is released.
        if this._imageList {
            WindowIcons.DestroyImageList(this._imageList)
            this._imageList := 0
        }

        this.Instance := ""
    }

    ; --- Selected-row highlighting ----------------------------------------

    static EnsureNotifyHook() {
        if !this._notifyHooked {
            OnMessage(0x004E, _WindowSwitcherNotify)   ; WM_NOTIFY
            this._notifyHooked := true
        }
    }

    ; Owner-drawn row background: a stronger surface for the selected row plus
    ; an accent edge, and a soft separator between idle rows. The control still
    ; draws the text and icons, so keyboard latency is unaffected.
    ; Returns "" (empty) for anything it does not draw, which keeps AutoHotkey
    ; and the control processing the message normally. Only custom-draw stages
    ; return a CDRF_* value.
    static OnNotify(lParam) {
        myGui := this.Instance

        if !IsObject(myGui) || !myGui.HasProp("ListView")
            return ""

        if !AppState.WindowSwitcherHighlightRow
            return ""

        lvHwnd := myGui.ListView.Hwnd

        if NumGet(lParam + 0, "Ptr") != lvHwnd
            return ""

        if NumGet(lParam + A_PtrSize * 2, "Int") != -12   ; NM_CUSTOMDRAW
            return ""

        ; NMCUSTOMDRAW layout (with pointer alignment taken into account).
        hdrSize := A_PtrSize * 3
        stageOff := hdrSize
        hdcOff := (A_PtrSize == 8) ? hdrSize + 8 : hdrSize + 4
        rcOff := hdcOff + A_PtrSize
        stateOff := rcOff + 16 + A_PtrSize
        clrTextOff := stateOff + 4 + (A_PtrSize == 8 ? 4 : 0) + A_PtrSize

        stage := NumGet(lParam + stageOff, "UInt")

        if stage == 1                                ; CDDS_PREPAINT
            return 0x20                              ; CDRF_NOTIFYITEMDRAW

        if stage != 0x10001                          ; CDDS_ITEMPREPAINT
            return ""

        hdc := NumGet(lParam + hdcOff, "Ptr")
        rcPtr := lParam + rcOff
        itemState := NumGet(lParam + stateOff, "UInt")
        selected := (itemState & 0x0001) ? true : false   ; CDIS_SELECTED

        if !this._dcBrush
            this._dcBrush := DllCall("GetStockObject", "Int", 18, "Ptr")   ; DC_BRUSH

        left := NumGet(rcPtr + 0, "Int")
        top := NumGet(rcPtr + 4, "Int")
        right := NumGet(rcPtr + 8, "Int")
        bottom := NumGet(rcPtr + 12, "Int")

        DllCall(
            "gdi32\SetDCBrushColor",
            "Ptr", hdc,
            "UInt", this.Cref(selected ? AppState.THEME_ELEVATED : AppState.THEME_CONTROL_BG)
        )
        DllCall("gdi32\FillRect", "Ptr", hdc, "Ptr", rcPtr, "Ptr", this._dcBrush)

        if selected {
            bar := Buffer(16, 0)
            NumPut("Int", left, bar, 0)
            NumPut("Int", top, bar, 4)
            NumPut("Int", left + 3, bar, 8)
            NumPut("Int", bottom, bar, 12)
            DllCall(
                "gdi32\SetDCBrushColor",
                "Ptr", hdc,
                "UInt", this.Cref(AppState.THEME_ACCENT)
            )
            DllCall("gdi32\FillRect", "Ptr", hdc, "Ptr", bar, "Ptr", this._dcBrush)
        } else {
            line := Buffer(16, 0)
            NumPut("Int", left, line, 0)
            NumPut("Int", bottom - 1, line, 4)
            NumPut("Int", right, line, 8)
            NumPut("Int", bottom, line, 12)
            DllCall(
                "gdi32\SetDCBrushColor",
                "Ptr", hdc,
                "UInt", this.Cref(AppState.THEME_SURFACE)
            )
            DllCall("gdi32\FillRect", "Ptr", hdc, "Ptr", line, "Ptr", this._dcBrush)
        }

        ; NMLVCUSTOMDRAW.clrText / clrTextBk: the control paints the text using
        ; these colours when CDRF_NEWFONT is returned.
        NumPut(
            "UInt",
            this.Cref(selected ? AppState.THEME_FG : AppState.THEME_FG_DIM),
            lParam + clrTextOff
        )
        NumPut("UInt", 0xFFFFFFFF, lParam + clrTextOff + 4)   ; CLR_NONE

        return 0x2   ; CDRF_NEWFONT
    }

    static Cref(colorStr) => ThemeHelper.RgbToColorRef(colorStr)
}

; WM_NOTIFY is shared by every control, so an empty return value is used for
; anything unrelated: that lets AutoHotkey keep dispatching ListView events for
; this and every other GUI.
_WindowSwitcherNotify(wParam, lParam, msg, hwnd) {
    result := ""

    try
        result := WindowSwitcherGui.OnNotify(lParam)
    catch
        result := ""

    return result
}
