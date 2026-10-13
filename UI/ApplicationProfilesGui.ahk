#Requires AutoHotkey v2.0

; Settings dialog for per-executable CapsLock-layer exclusions.
class ApplicationProfilesGui {
    static Instance := ""
    static RunningList := ""
    static RulesList := ""
    static Status := ""
    static RunningWindows := []
    static RuleEntries := []

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
        configureGroupsButton := ThemeHelper.AddButton(
            myGui,
            "x398 y258 w220 h30",
            Lang("GUI_APP_PROFILES_CONFIGURE_GROUPS")
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
        this.RuleEntries := []

        refreshButton.OnEvent("Click", (*) => ApplicationProfilesGui.Refresh())
        addButton.OnEvent("Click", (*) => ApplicationProfilesGui.AddSelectedExecutable())
        configureGroupsButton.OnEvent("Click", (*) => ApplicationProfilesGui.ConfigureSelectedGroups())
        removeButton.OnEvent("Click", (*) => ApplicationProfilesGui.RemoveSelectedRule())
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

        this.RuleEntries := []
        rulesList.Delete()

        disabledExecutables := ApplicationProfiles.NormalizeDisabledExecutables(
            AppState.DisabledHotkeyProcesses
        )
        for executableName in disabledExecutables {
            this.RuleEntries.Push({process: executableName, type: "all"})
            rulesList.Add(, executableName, Lang("GUI_APP_PROFILES_DISABLED"))
        }

        for executableName, groupIds in AppState.DisabledHotkeyGroups {
            if groupIds.Length == 0
                continue

            groupLabels := []
            for definition in ApplicationProfiles.GetShortcutGroups() {
                for disabledGroup in groupIds {
                    if disabledGroup == definition.id {
                        groupLabels.Push(Lang(definition.labelKey))
                        break
                    }
                }
            }

            this.RuleEntries.Push({process: executableName, type: "groups"})
            rulesList.Add(
                ,
                executableName,
                Lang("GUI_APP_PROFILES_GROUP_RULE", "", Join(groupLabels, ", "))
            )
        }

        if IsObject(this.Status) {
            this.Status.Text := this.RunningWindows.Length == 0
                ? Lang("GUI_APP_PROFILES_NO_WINDOWS")
                : Lang("GUI_APP_PROFILES_STATUS", "", this.RuleEntries.Length)
        }
    }

    static ConfigureSelectedGroups() {
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

        ApplicationProfilesGroupGui.Show(this.RunningWindows[selectedRow].process)
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

    static RemoveSelectedRule() {
        rulesList := this.RulesList
        if !IsObject(rulesList)
            return

        selectedRow := rulesList.GetNext(0, "Focused")
        if !selectedRow
            selectedRow := rulesList.GetNext(0)
        if !selectedRow || selectedRow > this.RuleEntries.Length {
            this.Status.Text := Lang("GUI_APP_PROFILES_SELECT_RULE")
            return
        }

        selectedRule := this.RuleEntries[selectedRow]
        try {
            if selectedRule.type == "all"
                wasRemoved := ApplicationProfiles.RemoveDisabledExecutable(selectedRule.process)
            else
                wasRemoved := ApplicationProfiles.SetDisabledGroups(selectedRule.process, [])
        } catch as caughtError {
            this.Status.Text := caughtError.Message
            return
        }

        if !wasRemoved
            return

        this.RefreshRules()
        this.Status.Text := selectedRule.type == "all"
            ? Lang("GUI_APP_PROFILES_REMOVED", "", selectedRule.process)
            : Lang("GUI_APP_PROFILES_GROUPS_REMOVED", "", selectedRule.process)
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
        this.RuleEntries := []
    }
}


; Modal editor for per-executable shortcut-group exclusions.
class ApplicationProfilesGroupGui {
    static Instance := ""
    static Executable := ""
    static CheckBoxes := Map()

    static Show(processName) {
        executableName := ApplicationProfiles.NormalizeExecutableName(processName)
        if executableName == ""
            return

        this.Close()
        myGui := Gui(
            "+AlwaysOnTop -MaximizeBox -MinimizeBox +ToolWindow",
            Lang("GUI_APP_PROFILES_GROUPS_TITLE", "", executableName)
        )
        ThemeHelper.StyleGui(myGui)
        ThemeHelper.AddTitle(
            myGui,
            "⌘ " Lang("GUI_APP_PROFILES_GROUPS_TITLE", "", executableName),
            640
        )
        ThemeHelper.AddSubtitle(myGui, Lang("GUI_APP_PROFILES_GROUPS_HINT"), 640)
        ThemeHelper.AddSeparator(myGui, 640)

        this.Executable := executableName
        this.CheckBoxes := Map()
        disabledGroups := ApplicationProfiles.GetDisabledGroups(executableName)
        rowY := 112

        for definition in ApplicationProfiles.GetShortcutGroups() {
            checkbox := myGui.Add(
                "Checkbox",
                ThemeHelper.GetCheckBoxOptions("x24 y" rowY " w630 h26"),
                Lang(definition.labelKey)
            )
            ThemeHelper.StyleCheckBox(checkbox)
            for disabledGroup in disabledGroups {
                if disabledGroup == definition.id {
                    checkbox.Value := 1
                    break
                }
            }
            this.CheckBoxes[definition.id] := checkbox
            rowY += 31
        }

        applyButton := ThemeHelper.AddButton(
            myGui,
            "x420 y" (rowY + 8) " w100 h30",
            Lang("GUI_APP_PROFILES_GROUPS_APPLY"),
            "primary"
        )
        cancelButton := ThemeHelper.AddButton(
            myGui,
            "x528 y" (rowY + 8) " w92 h30",
            Lang("GUI_APP_PROFILES_GROUPS_CANCEL")
        )

        applyButton.OnEvent("Click", (*) => ApplicationProfilesGroupGui.Apply())
        cancelButton.OnEvent("Click", (*) => ApplicationProfilesGroupGui.Close())
        myGui.OnEvent("Escape", (*) => ApplicationProfilesGroupGui.Close())
        myGui.OnEvent("Close", (*) => ApplicationProfilesGroupGui.Close())

        this.Instance := myGui
        ThemeHelper.ApplyWindowTheme(myGui.Hwnd)
        myGui.Show("w660 h" (rowY + 58) " Center")
    }

    static Apply() {
        if this.Executable == "" || !IsObject(this.Instance)
            return

        selectedGroups := []
        for groupId, checkbox in this.CheckBoxes {
            if checkbox.Value
                selectedGroups.Push(groupId)
        }

        try {
            if !ApplicationProfiles.SetDisabledGroups(this.Executable, selectedGroups)
                return
        } catch as caughtError {
            ShowToolTip(caughtError.Message, 2200)
            return
        }

        if IsObject(ApplicationProfilesGui.Status) {
            ApplicationProfilesGui.Status.Text := Lang(
                "GUI_APP_PROFILES_GROUPS_SAVED",
                "",
                this.Executable
            )
        }
        ApplicationProfilesGui.RefreshRules()
        ShowToolTip(
            Lang("GUI_APP_PROFILES_GROUPS_SAVED", "", this.Executable),
            1600
        )
        this.Close()
    }

    static Close() {
        if IsObject(this.Instance) {
            try this.Instance.Destroy()
        }

        this.Instance := ""
        this.Executable := ""
        this.CheckBoxes := Map()
    }
}
