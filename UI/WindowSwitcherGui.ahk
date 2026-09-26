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
    static _cursorHooked := false
    ; Row index (0-based) whose close strip is under the pointer, or -1.
    static _hoverRow := -1
    static _penCache := Map()

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

        ; Columns occupy exactly ContentWidth, leaving a strip on the right for
        ; the per-row close button. The strip is deliberately wider than a
        ; vertical scrollbar so the button is never painted underneath one.
        list.ModifyCol(1, 196)
        list.ModifyCol(2, showProcess ? 270 : 399)
        if showProcess
            list.ModifyCol(3, 129)

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

        ; Closes the selected window itself (the switcher stays open so several
        ; windows can be closed in one pass).
        closeWinBtn := ThemeHelper.AddButton(
            myGui,
            "x+8 w120",
            "✕ " Lang("GUI_WINDOW_SWITCHER_CLOSE_WIN", "Close window")
        )

        closeBtn := ThemeHelper.AddButton(
            myGui,
            "x+8 w90",
            "✕ " Lang("GUI_FULL_CLOSE", "Close")
        )

        ; Theme colours may have changed since the last session.
        this.ReleasePens()
        this._hoverRow := -1

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
            "Click",
            (ctrl, row) => WindowSwitcherGui.OnRowClick(row)
        )

        list.OnEvent(
            "DoubleClick",
            (ctrl, row) => WindowSwitcherGui.OnRowDoubleClick(row)
        )

        list.OnEvent(
            "ItemSelect",
            (*) => WindowSwitcherGui.UpdateStatus()
        )

        activateBtn.OnEvent(
            "Click",
            (*) => WindowSwitcherGui.ActivateSelected()
        )

        closeWinBtn.OnEvent(
            "Click",
            (*) => WindowSwitcherGui.CloseSelectedWindow()
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

    static Refresh(refreshWindows := true, keepRow := 0) {
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

        if visible.Length == 0 {
            this.UpdateStatus()
            return
        }

        ; After closing a row the selection stays where it was, so consecutive
        ; closes do not jump back to the top of the list.
        target := (keepRow > 0) ? Min(keepRow, visible.Length) : 1
        lv.Modify(target, "Select Focus")

        this.UpdateStatus()
    }

    ; --- Per-row close button ---------------------------------------------

    ; Columns occupy exactly ContentWidth (GUI units). The remaining strip on
    ; the right belongs to the close button and is wider than a scrollbar.
    static ContentWidth := 595
    static CloseStripWidth := 30

    ; GDI and cursor positions are in physical pixels, while control sizes are
    ; in GUI units, so everything below converts explicitly.
    static PxFactor() => (A_ScreenDPI ? A_ScreenDPI : 96) / 96

    static ContentRightPx() => Round(this.ContentWidth * this.PxFactor())

    static StripWidthPx() => Round(this.CloseStripWidth * this.PxFactor())

    ; True when the pointer is inside the close strip. The row itself comes
    ; from the ListView click notification, so only the horizontal band plus a
    ; vertical sanity check are needed here.
    static IsOverCloseStrip() {
        myGui := this.Instance

        if !IsObject(myGui) || !myGui.HasProp("ListView")
            return false

        lv := myGui.ListView

        pt := Buffer(8, 0)
        if !DllCall("user32\GetCursorPos", "Ptr", pt)
            return false

        if !DllCall("user32\ScreenToClient", "Ptr", lv.Hwnd, "Ptr", pt)
            return false

        x := NumGet(pt, 0, "Int")
        y := NumGet(pt, 4, "Int")

        width := 0
        height := 0

        try
            lv.GetPos(, , &width, &height)
        catch
            return false

        widthPx := Round(width * this.PxFactor())
        heightPx := Round(height * this.PxFactor())

        if widthPx <= 0 || heightPx <= 0
            return false

        if (y < 0) || (y > heightPx)
            return false

        right := this.ContentRightPx()

        return (x >= right - this.StripWidthPx()) && (x <= right)
    }

    ; Row under the pointer, 0-based, or -1. Used for hover feedback only.
    static HitTestRow() {
        myGui := this.Instance

        if !IsObject(myGui) || !myGui.HasProp("ListView")
            return -1

        lv := myGui.ListView

        pt := Buffer(8, 0)
        if !DllCall("user32\GetCursorPos", "Ptr", pt)
            return -1

        if !DllCall("user32\ScreenToClient", "Ptr", lv.Hwnd, "Ptr", pt)
            return -1

        ; LVHITTESTINFO: POINT pt, UINT flags, int iItem, int iSubItem
        hti := Buffer(20, 0)
        NumPut("Int", NumGet(pt, 0, "Int"), hti, 0)
        NumPut("Int", NumGet(pt, 4, "Int"), hti, 4)

        try
            SendMessage(0x1012, 0, hti.Ptr, , "ahk_id " lv.Hwnd)   ; LVM_HITTEST
        catch
            return -1

        return NumGet(hti, 12, "Int")
    }

    ; Refreshes the hover row. Returns true when it changed, so callers know
    ; whether a repaint is needed. Never repaint from inside a paint cycle.
    static UpdateHoverRow() {
        row := -1

        if this.IsOverCloseStrip()
            row := this.HitTestRow()

        if row == this._hoverRow
            return false

        this._hoverRow := row
        return true
    }

    static OnRowClick(row) {
        if this.IsOverCloseStrip() {
            this.CloseWindowAt(row)
            return
        }
    }

    static OnRowDoubleClick(row) {
        ; Double-clicking the close button must not activate the window.
        if this.IsOverCloseStrip() {
            this.CloseWindowAt(row)
            return
        }

        this.ActivateSelected()
    }

    ; --- Closing windows ---------------------------------------------------

    static CloseSelectedWindow() {
        myGui := this.Instance

        if !IsObject(myGui)
            return

        row := myGui.ListView.GetNext(0, "Focused")
        if !row
            row := myGui.ListView.GetNext(0)

        if !row {
            ShowToolTip(
                Lang("GUI_WINDOW_SWITCHER_EMPTY", "No matching windows found."),
                1600
            )
            return
        }

        this.CloseWindowAt(row)
    }

    ; Closes the window behind a row: a graceful WM_CLOSE first, and a
    ; confirmed process termination only when the window refuses to close.
    static CloseWindowAt(row) {
        myGui := this.Instance

        if !IsObject(myGui)
            return

        if !row || !myGui.HasProp("VisibleWindows") || row > myGui.VisibleWindows.Length
            return

        entry := myGui.VisibleWindows[row]
        hwnd := entry.hwnd
        label := entry.display != "" ? entry.display : entry.process

        if !WinExist("ahk_id " hwnd) {
            this.Refresh(true, row)
            return
        }

        posted := false
        try {
            DllCall(
                "user32\PostMessage",
                "Ptr",  hwnd,
                "UInt", 0x0010,   ; WM_CLOSE
                "Ptr",  0,
                "Ptr",  0
            )
            posted := true
        } catch
            posted := false

        if !posted {
            this.ReportCloseFailure()
            return
        }

        ; Give the application a moment to shut down on its own terms.
        closed := false
        Loop 20 {
            Sleep(50)
            if !WinExist("ahk_id " hwnd) {
                closed := true
                break
            }
        }

        if closed {
            this.Refresh(true, row)
            ShowToolTip(
                Lang("MSG_WS_WINDOW_CLOSED", "Closed: {1}.", label),
                1600
            )
            return
        }

        ; Still open: ask before ending the process, because forced termination
        ; can discard unsaved work.
        guiHwnd := myGui.Hwnd
        try
            WinSetAlwaysOnTop(0, "ahk_id " guiHwnd)

        answer := ""
        try
            answer := MsgBox(
                Lang(
                    "MSG_WS_FORCE_CONFIRM",
                    "{1} did not close. End its process? Unsaved work may be lost.",
                    label
                ),
                Lang("MSG_CONFIRM"),
                "YesNo Icon! 256"   ; 256 = default button 2 (No)
            )
        catch
            answer := "No"

        try
            WinSetAlwaysOnTop(1, "ahk_id " guiHwnd)

        if answer != "Yes" {
            ShowToolTip(
                Lang("MSG_WS_CLOSE_NO_RESPONSE", "{1} did not respond to the close request.", label),
                2200
            )
            return
        }

        ended := false
        try {
            ProcessClose(entry.pid)
            ended := true
        } catch
            ended := false

        if !ended {
            try {
                WinKill("ahk_id " hwnd)
                ended := true
            } catch
                ended := false
        }

        Sleep(80)
        this.Refresh(true, row)

        if ended {
            ShowToolTip(
                Lang("MSG_WS_FORCE_CLOSED", "{1} was ended forcefully.", label),
                2000
            )
        } else
            this.ReportCloseFailure()
    }

    static ReportCloseFailure() {
        ShowToolTip(
            Lang("MSG_WS_CLOSE_FAILED", "The selected window could not be closed."),
            2200
        )
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

        if !this._cursorHooked {
            OnMessage(0x0020, _WindowSwitcherSetCursor)   ; WM_SETCURSOR
            this._cursorHooked := true
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
        itemSpecOff := rcOff + 16
        stateOff := itemSpecOff + A_PtrSize
        clrTextOff := stateOff + 4 + (A_PtrSize == 8 ? 4 : 0) + A_PtrSize

        stage := NumGet(lParam + stageOff, "UInt")

        ; One paint cycle: recalibrate the hover row here rather than
        ; invalidating, since invalidating during a paint would loop forever.
        if stage == 1 {                              ; CDDS_PREPAINT
            this.UpdateHoverRow()
            return 0x20                              ; CDRF_NOTIFYITEMDRAW
        }

        ; The close button is painted after the row, independent of whether row
        ; highlighting is enabled.
        if stage == 0x10002 {                        ; CDDS_ITEMPOSTPAINT
            this.DrawCloseGlyph(
                NumGet(lParam + hdcOff, "Ptr"),
                lParam + rcOff,
                (NumGet(lParam + stateOff, "UInt") & 0x0001) ? true : false,
                NumGet(lParam + itemSpecOff, "Ptr")
            )
            return ""
        }

        if stage != 0x10001                          ; CDDS_ITEMPREPAINT
            return ""

        ; Row highlighting is optional. When it is off the control paints the
        ; row itself and only the post-paint pass is requested, so the close
        ; button stays available.
        if !AppState.WindowSwitcherHighlightRow
            return 0x10                              ; CDRF_NOTIFYPOSTPAINT

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

        ; Ask for a post-paint pass as well, which is where the per-row close
        ; button is drawn on top of the finished row.
        return 0x2 | 0x10   ; CDRF_NEWFONT | CDRF_NOTIFYPOSTPAINT
    }

    ; --- Per-row close button ---------------------------------------------

    ; A small "x" drawn with two GDI lines inside the reserved strip. Drawing
    ; it with lines rather than a glyph character means it never depends on a
    ; specific font containing U+2715, which is what made it invisible on some
    ; systems. It is painted in the post-paint stage, so it sits above the
    ; finished row.
    static DrawCloseGlyph(hdc, rcPtr, selected, rowIndex) {
        if !hdc
            return

        top := NumGet(rcPtr + 4, "Int")
        bottom := NumGet(rcPtr + 12, "Int")

        if bottom - top < 8
            return

        right := this.ContentRightPx()
        strip := this.StripWidthPx()

        cx := right - Round(strip / 2)
        cy := (top + bottom) // 2

        ; Keep the glyph proportional to the row height, which follows the
        ; configured row density.
        r := Round((bottom - top) * 0.17)
        if r < 3
            r := 3
        else if r > 6
            r := 6

        hot := (rowIndex == this._hoverRow) && this.IsOverCloseStrip()

        cref := this.Cref(
            hot ? AppState.THEME_DANGER
                : (selected ? AppState.THEME_FG_DIM : AppState.THEME_FG_MUTED)
        )

        hPen := this.EnsureClosePen(cref, hot)
        if !hPen
            return

        old := DllCall("gdi32\SelectObject", "Ptr", hdc, "Ptr", hPen, "Ptr")

        DllCall("gdi32\MoveToEx", "Ptr", hdc, "Int", cx - r, "Int", cy - r, "Ptr", 0)
        DllCall("gdi32\LineTo",   "Ptr", hdc, "Int", cx + r, "Int", cy + r)
        DllCall("gdi32\MoveToEx", "Ptr", hdc, "Int", cx + r, "Int", cy - r, "Ptr", 0)
        DllCall("gdi32\LineTo",   "Ptr", hdc, "Int", cx - r, "Int", cy + r)

        DllCall("gdi32\SelectObject", "Ptr", hdc, "Ptr", old, "Ptr")
    }

    ; Pens are cached per colour and width. The set is tiny (idle / selected /
    ; hover) so it is not worth creating and deleting them on every repaint.
    static EnsureClosePen(cref, thick) {
        key := cref "|" (thick ? 1 : 0)

        if this._penCache.Has(key)
            return this._penCache[key]

        hPen := 0
        try
            hPen := DllCall(
                "gdi32\CreatePen",
                "Int",  0,                    ; PS_SOLID
                "Int",  thick ? 2 : 1,
                "UInt", cref,
                "Ptr"
            )

        if hPen
            this._penCache[key] := hPen

        return hPen
    }

    static ReleasePens() {
        for key, hPen in this._penCache {
            if hPen
                try DllCall("gdi32\DeleteObject", "Ptr", hPen)
        }
        this._penCache := Map()
    }

    static Cref(colorStr) => ThemeHelper.RgbToColorRef(colorStr)
}

; WM_NOTIFY is shared by every control, so an empty return value is used for
; anything unrelated: that lets AutoHotkey keep dispatching ListView events for
; this and every other GUI.
; Shows the hand cursor while the pointer is over the per-row close strip, so
; the strip reads as a button without needing a hover repaint.
_WindowSwitcherSetCursor(wParam, lParam, msg, hwnd) {
    if !WindowSwitcherGui.IsOverCloseStrip()
        return ""

    ; Repaint only when the pointer crosses into another row's strip, so the
    ; hover colour updates without repainting on every mouse move.
    if WindowSwitcherGui.UpdateHoverRow() {
        try
            DllCall(
                "user32\InvalidateRect",
                "Ptr", WindowSwitcherGui.Instance.ListView.Hwnd,
                "Ptr", 0,
                "Int", 0
            )
        catch
            return ""
    }

    try {
        hCursor := DllCall("user32\LoadCursor", "Ptr", 0, "Ptr", 32649, "Ptr")   ; IDC_HAND
        if hCursor {
            DllCall("user32\SetCursor", "Ptr", hCursor)
            return 1
        }
    } catch
        return ""

    return ""
}

_WindowSwitcherNotify(wParam, lParam, msg, hwnd) {
    result := ""

    try
        result := WindowSwitcherGui.OnNotify(lParam)
    catch
        result := ""

    return result
}
