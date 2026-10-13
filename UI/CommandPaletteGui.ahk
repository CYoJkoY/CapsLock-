#Requires AutoHotkey v2.0

; ---------------------------------------------------------------------------
; Keyboard-first launcher for existing CapsLock- actions.
; It dispatches to existing functions and captures the external target before
; the palette takes foreground focus.
; ---------------------------------------------------------------------------
class CommandPaletteGui {
    static Instance := ""
    static SearchBox := ""
    static ListView := ""
    static Status := ""
    static Commands := []
    static VisibleCommands := []
    static Target := ""
    static RecentCommandIds := []
    static RecentCommandsLoaded := false
    static MaxRecentCommands := 5

    static Show() {
        if IsObject(this.Instance) {
            try {
                if WinExist("ahk_id " this.Instance.Hwnd) {
                    this.Instance.Show()
                    WinActivate("ahk_id " this.Instance.Hwnd)
                    this.SearchBox.Focus()
                    return
                }
            } catch {
            }
            this.Close()
        }

        this.LoadRecentCommands()
        this.Target := this.CaptureTarget()
        myGui := Gui("+AlwaysOnTop -MaximizeBox -MinimizeBox +ToolWindow", Lang("GUI_COMMAND_PALETTE_TITLE"))
        ThemeHelper.StyleGui(myGui)
        myGui.OnEvent("Escape", (*) => CommandPaletteGui.Close())
        myGui.OnEvent("Close", (*) => CommandPaletteGui.Close())

        ThemeHelper.AddTitle(myGui, "⌘ " Lang("GUI_COMMAND_PALETTE_TITLE"), 660)
        ThemeHelper.AddSubtitle(myGui, Lang("GUI_COMMAND_PALETTE_HINT"), 660)
        ThemeHelper.AddSeparator(myGui, 660)

        search := myGui.Add("Edit", "w660 r1 y+12 " ThemeHelper.GetEditOptions(), "")
        ThemeHelper.StyleEdit(search)

        list := myGui.Add(
            "ListView",
            "w660 r12 y+10 -Multi " ThemeHelper.GetLVOptions(),
            [
                Lang("GUI_COMMAND_PALETTE_COL_COMMAND"),
                Lang("GUI_COMMAND_PALETTE_COL_DESCRIPTION"),
                Lang("GUI_COMMAND_PALETTE_COL_SHORTCUT")
            ]
        )
        list.ModifyCol(1, 240)
        list.ModifyCol(2, 310)
        list.ModifyCol(3, 100)
        ThemeHelper.StyleListView(list)

        status := myGui.Add("Text", "w660 y+8", "")
        ThemeHelper.MarkDim(status)

        myGui.SearchBox := search
        myGui.ListView := list
        myGui.Status := status
        this.Instance := myGui
        this.SearchBox := search
        this.ListView := list
        this.Status := status
        this.Commands := this.BuildCommands(this.Target)
        this.VisibleCommands := []

        search.OnEvent("Change", (*) => CommandPaletteGui.Refresh())
        list.OnEvent("DoubleClick", (ctrl, row) => CommandPaletteGui.RunSelected(row))
        list.OnEvent("ItemSelect", (*) => CommandPaletteGui.UpdateStatus())

        ThemeHelper.ApplyWindowTheme(myGui.Hwnd)
        myGui.Show("w700 h520 Center")
        search.Focus()
        this.Refresh()
    }

    static CaptureTarget() {
        try
            return QuickPhraseCaptureExternalTarget()
        catch
            return ""
    }

    static BuildCommands(target) {
        commands := []

        commands.Push({
            id: "settings",
            label: Lang("MENU_SETTINGS"),
            category: Lang("SET_NAV_GENERAL"),
            description: Lang("GUI_SETTINGS_TITLE"),
            shortcut: "CapsLock + I / ,",
            keywords: "settings preferences configuration controls",
            restoreTarget: false,
            action: (*) => ShowSettingsGui()
        })
        commands.Push({
            id: "quick-phrase-manager",
            label: Lang("MENU_QUICK_PHRASE_MANAGE"),
            category: Lang("SET_NAV_INTEGRATION"),
            description: Lang("GUI_QUICK_PHRASE_TITLE"),
            shortcut: "",
            keywords: "quick phrase snippets templates manager",
            restoreTarget: false,
            action: (*) => ShowQuickPhraseManager()
        })
        commands.Push({
            id: "window-switcher",
            label: Lang("GUI_WINDOW_SWITCHER_TITLE"),
            category: Lang("CHEAT_CAT_WINDOW"),
            description: Lang("CHEAT_ACT_WINDOW_SWITCH"),
            shortcut: "CapsLock + L",
            keywords: "window app application activate switch focus",
            restoreTarget: false,
            action: (*) => WindowSwitcherGui.Show()
        })
        commands.Push({
            id: "hotkey-reference",
            label: Lang("CHEAT_TITLE"),
            category: Lang("CHEAT_CAT_HELP"),
            description: Lang("CHEAT_HINT"),
            shortcut: "CapsLock + H / F1",
            keywords: "hotkey shortcut help reference cheatsheet",
            restoreTarget: false,
            action: (*) => OpenCheatsheetFromTray()
        })
        commands.Push({
            id: "theme-toggle",
            label: Lang("MENU_THEME"),
            category: Lang("SET_NAV_GENERAL"),
            description: Theme.Label(Theme.Current),
            shortcut: "",
            keywords: "theme appearance light dark",
            restoreTarget: false,
            action: (*) => Theme.Toggle()
        })
        commands.Push({
            id: "temp-folder",
            label: Lang("MENU_OPEN_TEMP"),
            category: Lang("CHEAT_CAT_FILES"),
            description: Lang("CHEAT_ACT_TEMP"),
            shortcut: "CapsLock + Alt + Q",
            keywords: "temporary temp folder files",
            restoreTarget: false,
            action: (*) => OpenTempFolder()
        })
        commands.Push({
            id: "cloud-sync",
            label: Lang("MENU_CLOUD_SYNC_NOW"),
            category: Lang("SET_NAV_INTEGRATION"),
            description: Lang("SET_NAV_INTEGRATION"),
            shortcut: "",
            keywords: "cloud sync synchronize backup",
            restoreTarget: false,
            action: (*) => (AppState.CloudSyncEnabled ? CloudSyncCoordinator.SyncNow() : ShowCloudSyncSettings())
        })

        commands.Push({
            id: "spotlight",
            label: Lang("CHEAT_ACT_SPOTLIGHT"),
            category: Lang("CHEAT_CAT_VISUAL"),
            description: Lang("CHEAT_ACT_SPOTLIGHT"),
            shortcut: "CapsLock + O",
            keywords: "mouse spotlight focus dim screen",
            restoreTarget: false,
            action: (*) => Spotlight.Toggle()
        })
        commands.Push({
            id: "dynamic-zoom",
            label: Lang("CHEAT_ACT_ZOOM"),
            category: Lang("CHEAT_CAT_VISUAL"),
            description: Lang("CHEAT_ACT_ZOOM"),
            shortcut: "CapsLock + Z",
            keywords: "magnify zoom screen cursor",
            restoreTarget: false,
            action: (*) => Zoom.Toggle()
        })
        if IsObject(target) {
            commands.Push({
                id: "clipboard-menu",
                label: Lang("CHEAT_ACT_HISTORY"),
                category: Lang("CHEAT_CAT_CLIPBOARD"),
                description: Lang("GUI_FULL_TITLE"),
                shortcut: "CapsLock + Shift + V",
                keywords: "clipboard recent history paste",
                restoreTarget: true,
                action: (*) => ShowHistoryMenu()
            })
            commands.Push({
                id: "clipboard-full-history",
                label: Lang("GUI_FULL_TITLE"),
                category: Lang("CHEAT_CAT_CLIPBOARD"),
                description: Lang("CHEAT_ACT_HISTORY"),
                shortcut: "",
                keywords: "clipboard search manage select delete batch",
                restoreTarget: true,
                action: (*) => ShowFullHistoryGui()
            })
            commands.Push({
                id: "quick-phrase-selector",
                label: Lang("GUI_QUICK_PHRASE_TITLE"),
                category: Lang("SET_NAV_INTEGRATION"),
                description: Lang("CHEAT_ACT_QUICK_PHRASE"),
                shortcut: "CapsLock + Shift + P",
                keywords: "quick phrase snippets template insert text",
                restoreTarget: false,
                action: (*) => CommandPaletteGui.OpenQuickPhraseSelector(target)
            })
            commands.Push({
                id: "copy-plain-text",
                label: Lang("CHEAT_ACT_COPY_PLAIN"),
                category: Lang("CHEAT_CAT_CLIPBOARD"),
                description: Lang("CHEAT_ACT_COPY_PLAIN"),
                shortcut: "CapsLock + C",
                keywords: "copy plain text selection clipboard",
                restoreTarget: true,
                action: (*) => CopyAsPlainTextAndAddToHistory()
            })
            commands.Push({
                id: "change-case",
                label: Lang("CHEAT_ACT_CASE"),
                category: Lang("CHEAT_CAT_EDIT"),
                description: Lang("CHEAT_ACT_CASE"),
                shortcut: "CapsLock + F",
                keywords: "uppercase lowercase case transform text",
                restoreTarget: true,
                action: (*) => ChangeCaseOfLastCopy()
            })
            commands.Push({
                id: "pandoc-convert",
                label: Lang("CHEAT_ACT_PANDOC"),
                category: Lang("CHEAT_CAT_DOCUMENTS"),
                description: Lang("CHEAT_ACT_PANDOC"),
                shortcut: "CapsLock + P",
                keywords: "document convert file path pandoc",
                restoreTarget: true,
                action: (*) => ConvertWithPandoc()
            })
            commands.Push({
                id: "always-on-top",
                label: Lang("CHEAT_ACT_TOPMOST"),
                category: Lang("CHEAT_CAT_WINDOW"),
                description: Lang("CHEAT_ACT_TOPMOST"),
                shortcut: "CapsLock + T",
                keywords: "pin topmost keep visible window",
                restoreTarget: true,
                action: (*) => ToggleAlwaysOnTopWithOSD()
            })
            commands.Push({
                id: "borderless-fullscreen",
                label: Lang("CHEAT_ACT_BORDERLESS"),
                category: Lang("CHEAT_CAT_WINDOW"),
                description: Lang("CHEAT_ACT_BORDERLESS"),
                shortcut: "CapsLock + Shift + W / 8",
                keywords: "window fullscreen borderless full screen",
                restoreTarget: true,
                action: (*) => WindowFullScreen.Toggle()
            })
            commands.Push({
                id: "hide-window-to-tray",
                label: Lang("CHEAT_ACT_HIDE_TRAY"),
                category: Lang("CHEAT_CAT_WINDOW"),
                description: Lang("CHEAT_ACT_HIDE_TRAY"),
                shortcut: "CapsLock + Shift + S / 2",
                keywords: "hide window tray restore",
                restoreTarget: true,
                action: (*) => TrayHider.HideActive()
            })
            commands.Push({
                id: "window-hole",
                label: Lang("CHEAT_ACT_WINDOW_HOLE"),
                category: Lang("CHEAT_CAT_WINDOW"),
                description: Lang("CHEAT_ACT_WINDOW_HOLE"),
                shortcut: "CapsLock + X",
                keywords: "window hole penetrate underlying window",
                restoreTarget: true,
                action: (*) => WindowHole.Toggle()
            })

        }

        return commands
    }

    static Refresh() {
        list := this.ListView
        if !IsObject(list)
            return

        rawSearch := ""
        try
            rawSearch := StrLower(Trim(this.SearchBox.Text, " `t`r`n"))
        catch
            rawSearch := ""

        searchTerms := []
        searchPhrase := ""
        for searchTerm in StrSplit(rawSearch, [A_Space, A_Tab, "`r", "`n"], " `t`r`n") {
            if searchTerm == ""
                continue

            searchTerms.Push(searchTerm)
            searchPhrase .= (searchPhrase == "" ? "" : A_Space) searchTerm
        }

        rankedCommands := []
        for commandIndex, commandEntry in this.Commands {
            matchScore := this.GetMatchScore(commandEntry, searchPhrase, searchTerms)
            if matchScore < 0
                continue

            ; Surface recents only for an empty query. Explicit searches keep
            ; the established relevance ranking unchanged.
            if searchTerms.Length == 0 {
                recentRank := this.GetRecentCommandRank(commandEntry.id)
                if recentRank > 0
                    matchScore := 1000 - recentRank
            }

            rankedEntry := {item: commandEntry, score: matchScore}
            insertIndex := rankedCommands.Length + 1
            for rankedIndex, existingRank in rankedCommands {
                if matchScore > existingRank.score {
                    insertIndex := rankedIndex
                    break
                }
            }

            ; Insert before strictly weaker results only. Equal scores stay in
            ; their original registration order, including when the query is blank.
            rankedCommands.InsertAt(insertIndex, rankedEntry)
        }

        this.VisibleCommands := []
        SendMessage(0x000B, 0, 0, list.Hwnd)
        list.Delete()

        for rankedEntry in rankedCommands {
            commandEntry := rankedEntry.item
            this.VisibleCommands.Push(commandEntry)
            list.Add(, commandEntry.label, commandEntry.description, commandEntry.shortcut)
        }

        SendMessage(0x000B, 1, 0, list.Hwnd)
        if this.VisibleCommands.Length > 0
            list.Modify(1, "Select Focus Vis")

        this.UpdateStatus()
    }

    static GetMatchScore(commandEntry, searchPhrase, searchTerms) {
        if searchTerms.Length == 0
            return 0

        labelText := StrLower(commandEntry.label)
        descriptionText := StrLower(commandEntry.description)
        categoryText := StrLower(commandEntry.category)
        shortcutText := StrLower(commandEntry.shortcut)
        keywordText := StrLower(commandEntry.keywords)
        searchableText := labelText " "
            descriptionText " "
            categoryText " "
            shortcutText " "
            keywordText

        ; Multi-term search uses AND semantics across the existing searchable
        ; fields: every term must be present somewhere in the indexed text.
        for searchTerm in searchTerms {
            if !InStr(searchableText, searchTerm)
                return -1
        }

        matchScore := 0
        if labelText == searchPhrase
            matchScore += 10000
        else if SubStr(labelText, 1, StrLen(searchPhrase)) == searchPhrase
            matchScore += 5000
        else if InStr(labelText, searchPhrase)
            matchScore += 2500

        ; Prefer label matches, then descriptive fields. For labels, a match at
        ; the start or after a non-letter/digit boundary scores above an
        ; arbitrary substring. Lowercase matching keeps the current semantics.
        for searchTerm in searchTerms {
            termScore := 0
            labelPosition := InStr(labelText, searchTerm)
            if labelPosition == 1 {
                termScore := 700
            } else if labelPosition > 1 {
                precedingCharacter := SubStr(labelText, labelPosition - 1, 1)
                termScore := RegExMatch(precedingCharacter, "^[\p{L}\p{N}]$")
                    ? 500
                    : 620
            }

            if InStr(descriptionText, searchTerm)
                termScore := Max(termScore, 240)
            if InStr(categoryText, searchTerm)
                termScore := Max(termScore, 220)
            if InStr(shortcutText, searchTerm)
                termScore := Max(termScore, 200)
            if InStr(keywordText, searchTerm)
                termScore := Max(termScore, 180)

            matchScore += termScore
        }

        return matchScore
    }

    static LoadRecentCommands() {
        if this.RecentCommandsLoaded
            return

        this.RecentCommandsLoaded := true
        this.RecentCommandIds := []
        raw := ""

        try
            raw := IniRead(AppState.ConfigFile, "CommandPalette", "recentCommands", "")
        catch
            raw := ""

        seen := Map()
        for rawId in StrSplit(raw, ",") {
            commandId := Trim(rawId)
            if !(commandId ~= "^[a-z0-9-]+$")
                continue

            if seen.Has(commandId)
                continue

            seen[commandId] := true
            this.RecentCommandIds.Push(commandId)
            if this.RecentCommandIds.Length >= this.MaxRecentCommands
                break
        }
    }

    static GetRecentCommandRank(commandId) {
        this.LoadRecentCommands()
        for rank, recentId in this.RecentCommandIds {
            if recentId == commandId
                return rank
        }
        return 0
    }

    static RememberCommand(commandId) {
        if !(commandId ~= "^[a-z0-9-]+$")
            return

        this.LoadRecentCommands()
        updated := [commandId]
        for recentId in this.RecentCommandIds {
            if recentId == commandId
                continue
            updated.Push(recentId)
            if updated.Length >= this.MaxRecentCommands
                break
        }

        this.RecentCommandIds := updated

        ; Usage history is local-only. Do not mark Cloud Sync dirty or add it
        ; to the cloud-sync model.
        try
            IniWrite(Join(this.RecentCommandIds, ","), AppState.ConfigFile, "CommandPalette", "recentCommands")
        catch
            return
    }

    static UpdateStatus() {
        if !IsObject(this.Status)
            return

        visibleCount := this.VisibleCommands.Length
        totalCount := this.Commands.Length
        this.Status.Text := visibleCount == 0
            ? Lang("GUI_COMMAND_PALETTE_EMPTY")
            : Lang("GUI_COMMAND_PALETTE_STATUS", "", visibleCount, totalCount)
    }

    static MoveSelection(delta) {
        list := this.ListView
        if !IsObject(list)
            return

        count := list.GetCount()
        if count == 0
            return

        row := list.GetNext(0, "Focused")
        if !row
            row := list.GetNext(0)
        if !row
            row := 1

        row := Min(Max(row + delta, 1), count)
        list.Modify(row, "Select Focus Vis")
    }

    static RunSelected(requestedRow := 0) {
        list := this.ListView
        if !IsObject(list)
            return

        row := requestedRow
        if row < 1 || row > this.VisibleCommands.Length {
            row := list.GetNext(0, "Focused")
            if !row
                row := list.GetNext(0)
        }
        if row < 1 || row > this.VisibleCommands.Length
            return

        selectedCommand := this.VisibleCommands[row]
        target := this.Target
        this.Close()
        SetTimer(() => CommandPaletteGui.Execute(selectedCommand, target), -100)
    }

    static Execute(selectedCommand, target) {
        if selectedCommand.restoreTarget {
            if !IsObject(target) || !target.HasProp("window") || !WinExist("ahk_id " target.window) {
                ShowToolTip(Lang("MSG_TARGET_WINDOW_GONE", "", "The target window is no longer available."), 1800)
                return
            }

            WinActivate("ahk_id " target.window)
            if !WinWaitActive("ahk_id " target.window, , 1) {
                ShowToolTip(
                    Lang("MSG_COMMAND_PALETTE_TARGET_ACTIVATION_FAILED"),
                    1800
                )
                return
            }
        }

        try {
            selectedCommand.action.Call()
            this.RememberCommand(selectedCommand.id)
        } catch as caughtError
            ShowToolTip(caughtError.Message, 2200)
    }

    static OpenQuickPhraseSelector(target) {
        if !IsObject(target) || !target.HasProp("window") || !WinExist("ahk_id " target.window) {
            ShowToolTip(Lang("MSG_TARGET_WINDOW_GONE", "", "The target window is no longer available."), 1800)
            return
        }

        AppState.QuickPhraseExternalTarget := target
        ShowQuickPhraseSelector()
    }

    static Close() {
        if IsObject(this.Instance)
            try this.Instance.Destroy()

        this.Instance := ""
        this.SearchBox := ""
        this.ListView := ""
        this.Status := ""
        this.Commands := []
        this.VisibleCommands := []
        this.Target := ""
    }
}
