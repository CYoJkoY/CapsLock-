#Requires AutoHotkey v2.0

; Settings dialog for per-executable CapsLock-layer exclusions.
class ApplicationProfilesGui {
    static Instance := ""
    static RunningList := ""
    static RulesList := ""
    static Status := ""
    static RunningWindows := []
    static RuleExecutables := []

    static Show() {
        if IsObject(this.Instance) {
            try {
                if WinExist("ahk_id " this.Instance.Hwnd) {
                    this.Instance.Show()
                    WinActivate("ahk_id " this.Instance.Hwnd)
                    this.Refresh()
                    return
                }
            } catch {
            }
            this.Close()
        }

        myGui := Gui(
            "+AlwaysOnTop -MaximizeBox -MinimizeBox +ToolWindow",
            Lang("GUI_APP_PROFILES_TITLE")
        )
        ThemeHelper.StyleGui(myGui)
        ThemeHelper.AddTitle(myGui, "🪟 " Lang("GUI_APP_PROFILES_TITLE"), 688)
        ThemeHelper.AddSubtitle(myGui, Lang("GUI_APP_PROFILES_HINT"), 688)
        ThemeHelper.AddSeparator(myGui, 688)

        myGui.SetFont("s10 Bold c" Theme.Primary, Theme.Font)
        runningHeading := myGui.Add(
            "Text",
            "x16 y94 w688 h20 Background" Theme.Background,
            Lang("GUI_APP_PROFILES_RUNNING")
        )
        ThemeHelper.MarkSurface(runningHeading, Theme.Primary, Theme.Background)

        myGui.SetFont("s10 c" Theme.Text, Theme.Font)
        runningList := myGui.Add(
            "ListView",
            "x16 y116 w688 h132 -Multi " ThemeHelper.GetLVOptions(),
            [Lang("GUI_APP_PROFILES_COL_PROCESS"), Lang("GUI_APP_PROFILES_COL_WINDOW")]
        )
        runningList.ModifyCol(1, 180)
        runningList.ModifyCol(2, 480)
        ThemeHelper.StyleListView(runningList)

        refreshButton := ThemeHelper.AddButton(myGui, "x16 y258 w112 h30", "↻ " Lang("GUI_APP_PROFILES_REFRESH"))
        addButton := ThemeHelper.AddButton(
            myGui,
            "x138 y258 w250 h30",
            "⊘ " Lang("GUI_APP_PROFILES_DISABLE_SELECTED"),
            "primary"
        )

        myGui.SetFont("s10 Bold c" Theme.Primary, Theme.Font)
        rulesHeading := myGui.Add(
            "Text",
            "x16 y300 w688 h20 Background" Theme.Background,
            Lang("GUI_APP_PROFILES_RULES")
        )
        ThemeHelper.MarkSurface(rulesHeading, Theme.Primary, Theme.Background)

        myGui.SetFont("s10 c" Theme.Text, Theme.Font)
        rulesList := myGui.Add(
            "ListView",
            "x16 y322 w688 h112 -Multi " ThemeHelper.GetLVOptions(),
            [Lang("GUI_APP_PROFILES_COL_PROCESS"), Lang("GUI_APP_PROFILES_COL_RULE")]
        )
        rulesList.ModifyCol(1, 230)
        rulesList.ModifyCol(2, 430)
        ThemeHelper.StyleListView(rulesList)

        removeButton := ThemeHelper.AddButton(
            myGui,
            "x16 y444 w190 h30",
            "− " Lang("GUI_APP_PROFILES_REMOVE_SELECTED"),
            "danger"
        )
        closeButton := ThemeHelper.AddButton(
            myGui,
            "x612 y444 w92 h30",
            Lang("GUI_APP_PROFILES_CLOSE")
        )

        myGui.SetFont("s8 c" Theme.TextSecondary, Theme.Font)
        status := myGui.Add("Text", "x216 y449 w386 h22", "")
        ThemeHelper.MarkDim(status)

        myGui.RunningList := runningList
        myGui.RulesList := rulesList
        myGui.Status := status
        this.Instance := myGui
        this.RunningList := runningList
        this.RulesList := rulesList
        this.Status := status
        this.RunningWindows := []
        this.RuleExecutables := []

        refreshButton.OnEvent("Click", (*) => ApplicationProfilesGui.Refresh())
        addButton.OnEvent("Click", (*) => ApplicationProfilesGui.AddSelectedExecutable())
        removeButton.OnEvent("Click", (*) => ApplicationProfilesGui.RemoveSelectedExecutable())
        closeButton.OnEvent("Click", (*) => ApplicationProfilesGui.Close())
        runningList.OnEvent("DoubleClick", (ctrl, row) => ApplicationProfilesGui.AddSelectedExecutable())
        myGui.OnEvent("Escape", (*) => ApplicationProfilesGui.Close())
        myGui.OnEvent("Close", (*) => ApplicationProfilesGui.Close())

        ThemeHelper.ApplyWindowTheme(myGui.Hwnd)
        myGui.Show("w720 h492 Center")
        this.Refresh()
    }

    static Refresh() {
        if !IsObject(this.Instance)
            return
        this.RefreshRunningWindows()
        this.RefreshRules()
    }

    static RefreshRunningWindows() {
        runningList := this.RunningList
        if !IsObject(runningList)
            return

        this.RunningWindows := []
        runningList.Delete()
        ownPid := DllCall("GetCurrentProcessId", "UInt")

        try {
            windowHandles := WinGetList()
        } catch {
            windowHandles := []
        }

        for windowHwnd in windowHandles {
            try {
                if !DllCall("user32\IsWindowVisible", "Ptr", windowHwnd, "Int")
                    continue
                if WinGetPID("ahk_id " windowHwnd) == ownPid
                    continue

                windowTitle := Trim(WinGetTitle("ahk_id " windowHwnd))
                if windowTitle == ""
                    continue

                processName := ApplicationProfiles.NormalizeExecutableName(
                    WinGetProcessName("ahk_id " windowHwnd)
                )
                if processName == ""
                    continue

                windowTitle := RegExReplace(windowTitle, "[\r\n]+", " ")
                this.RunningWindows.Push({process: processName, title: windowTitle})
            } catch {
                continue
            }
        }

        for entry in this.RunningWindows
            runningList.Add(, entry.process, entry.title)
    }

    static RefreshRules() {
        rulesList := this.RulesList
        if !IsObject(rulesList)
            return

        this.RuleExecutables := ApplicationProfiles.NormalizeDisabledExecutables(
            AppState.DisabledHotkeyProcesses
        )
        rulesList.Delete()

        for executableName in this.RuleExecutables
            rulesList.Add(, executableName, Lang("GUI_APP_PROFILES_DISABLED"))

        if IsObject(this.Status) {
            this.Status.Text := this.RunningWindows.Length == 0
                ? Lang("GUI_APP_PROFILES_NO_WINDOWS")
                : Lang("GUI_APP_PROFILES_STATUS", "", this.RuleExecutables.Length)
        }
    }

    static AddSelectedExecutable() {
        runningList := this.RunningList
        if !IsObject(runningList)
            return

        selectedRow := runningList.GetNext(0, "Focused")
        if !selectedRow
            selectedRow := runningList.GetNext(0)
        if !selectedRow || selectedRow > this.RunningWindows.Length {
            this.Status.Text := Lang("GUI_APP_PROFILES_SELECT_RUNNING")
            return
        }

        executableName := this.RunningWindows[selectedRow].process
        try {
            wasAdded := ApplicationProfiles.AddDisabledExecutable(executableName)
        } catch as caughtError {
            this.Status.Text := caughtError.Message
            return
        }

        if !wasAdded {
            this.Status.Text := Lang("GUI_APP_PROFILES_EXISTS", "", executableName)
            return
        }

        this.RefreshRules()
        this.Status.Text := Lang("GUI_APP_PROFILES_ADDED", "", executableName)
    }

    static RemoveSelectedExecutable() {
        rulesList := this.RulesList
        if !IsObject(rulesList)
            return

        selectedRow := rulesList.GetNext(0, "Focused")
        if !selectedRow
            selectedRow := rulesList.GetNext(0)
        if !selectedRow || selectedRow > this.RuleExecutables.Length {
            this.Status.Text := Lang("GUI_APP_PROFILES_SELECT_RULE")
            return
        }

        executableName := this.RuleExecutables[selectedRow]
        try {
            wasRemoved := ApplicationProfiles.RemoveDisabledExecutable(executableName)
        } catch as caughtError {
            this.Status.Text := caughtError.Message
            return
        }

        if !wasRemoved
            return

        this.RefreshRules()
        this.Status.Text := Lang("GUI_APP_PROFILES_REMOVED", "", executableName)
    }

    static Close() {
        if IsObject(this.Instance) {
            try this.Instance.Destroy()
        }

        this.Instance := ""
        this.RunningList := ""
        this.RulesList := ""
        this.Status := ""
        this.RunningWindows := []
        this.RuleExecutables := []
    }
}
