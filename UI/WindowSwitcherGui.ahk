#Requires AutoHotkey v2.0

class WindowSwitcherGui {
    static Gui := ""

    static Show() {
        this.Close()

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

        list := myGui.Add(
            "ListView",
            "w640 r15 y+10 -Multi " ThemeHelper.GetLVOptions(),
            [
                Lang("GUI_WINDOW_SWITCHER_COL_PROCESS", "Application"),
                Lang("GUI_WINDOW_SWITCHER_COL_TITLE", "Window")
            ]
        )

        list.ModifyCol(1, 190)
        list.ModifyCol(2, 430)

        ThemeHelper.StyleListView(list)

        status := myGui.Add(
            "Text",
            "w640 y+8",
            ""
        )

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

        search.OnEvent(
            "Change",
            (*) => WindowSwitcherGui.Refresh()
        )

        list.OnEvent(
            "DoubleClick",
            (*) => WindowSwitcherGui.ActivateSelected()
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

        this.Gui := myGui

        ThemeHelper.ApplyImmersiveDarkMode(myGui.Hwnd)

        myGui.Show("w680 h520")

        this.Refresh()
        search.Focus()
    }

    static Refresh() {
        myGui := this.Gui

        if !IsObject(myGui) || !IsObject(myGui.ListView)
            return

        filter := ""

        try
            filter := StrLower(Trim(myGui.SearchBox.Text))
        catch
            filter := ""

        windows := this.CollectWindows()
        visible := []

        myGui.ListView.Delete()

        for entry in windows {
            searchText := StrLower(
                entry.process " " entry.title
            )

            if filter != "" && !InStr(searchText, filter)
                continue

            visible.Push(entry)

            myGui.ListView.Add(
                ,
                entry.process,
                entry.title
            )
        }

        myGui.VisibleWindows := visible

        count := visible.Length

        if count == 0 {
            myGui.Status.Text := Lang(
                "GUI_WINDOW_SWITCHER_EMPTY",
                "No matching windows found."
            )
            return
        }

        myGui.Status.Text := Lang(
            "GUI_WINDOW_SWITCHER_STATUS",
            "{1} window(s)",
            count
        )

        myGui.ListView.Modify(1, "Select Focus")
    }

    static CollectWindows() {
        result := []
        processNames := Map()

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

                if processNames.Has(pid)
                    processName := processNames[pid]
                else {
                    processName := ""
                    try
                        processName := WinGetProcessName("ahk_id " hwnd)
                    catch
                        continue

                    if processName == ""
                        continue

                    processNames[pid] := processName
                }

                result.Push({
                    hwnd: hwnd,
                    pid: pid,
                    process: processName,
                    title: title
                })
            }
        } catch {
        }

        return result
    }

    static ActivateSelected() {
        myGui := this.Gui

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
            this.Refresh()
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

    static Close() {
        if IsObject(this.Gui) {
            try
                this.Gui.Destroy()
        }

        this.Gui := ""
    }
}
