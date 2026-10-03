#Requires AutoHotkey v2.0

class CloudSyncConflictGui {
    static Show() {
        myGui := Gui("+AlwaysOnTop -MaximizeBox -MinimizeBox", Lang("GUI_CLOUD_SYNC_CONFLICT_TITLE", "Cloud Sync Conflict"))
        ThemeHelper.StyleGui(myGui)

        ThemeHelper.AddTitle(
            myGui,
            "⚠ " Lang("GUI_CLOUD_SYNC_CONFLICT_TITLE", "Cloud Sync Conflict"),
            520
        )
        ThemeHelper.AddSubtitle(
            myGui,
            Lang(
                "GUI_CLOUD_SYNC_CONFLICT_SUBTITLE",
                "Local and remote data changed since the last successful synchronization."
            ),
            520
        )
        ThemeHelper.AddSeparator(myGui, 520)

        myGui.Add(
            "Text",
            "w520 y+14",
            Lang(
                "GUI_CLOUD_SYNC_CONFLICT_ACTION",
                "Choose how to resolve the conflict. Keep Local uploads your current data; Use Remote replaces local data; Merge performs a three-way merge where possible."
            )
        )

        localBtn := ThemeHelper.AddButton(
            myGui,
            "Default w150 y+20",
            Lang("GUI_CLOUD_SYNC_KEEP_LOCAL", "Keep Local"),
            "primary"
        )
        remoteBtn := ThemeHelper.AddButton(
            myGui,
            "x+8 w150",
            Lang("GUI_CLOUD_SYNC_USE_REMOTE", "Use Remote")
        )
        mergeBtn := ThemeHelper.AddButton(
            myGui,
            "x+8 w150",
            Lang("GUI_CLOUD_SYNC_MERGE", "Merge")
        )
        cancelBtn := ThemeHelper.AddButton(
            myGui,
            "x+8 w90",
            Lang("GUI_CLOUD_SYNC_CANCEL", "Cancel")
        )

        Resolve(result) {
            myGui.Destroy()

            if result
                ShowToolTip(
                    Lang("MSG_CLOUD_SYNC_RESOLVED", "Cloud Sync conflict resolution completed."),
                    2000
                )
            else
                ShowToolTip(
                    Lang("MSG_CLOUD_SYNC_CONFLICT", "Cloud Sync conflict remains unresolved."),
                    2400
                )
        }

        localBtn.OnEvent("Click", (*) => Resolve(CloudSyncCoordinator.ResolveKeepLocal()))
        remoteBtn.OnEvent("Click", (*) => Resolve(CloudSyncCoordinator.ResolveUseRemote()))
        mergeBtn.OnEvent("Click", (*) => Resolve(CloudSyncCoordinator.ResolveMerge()))
        cancelBtn.OnEvent("Click", (*) => myGui.Destroy())

        myGui.OnEvent("Escape", (*) => myGui.Destroy())
        myGui.OnEvent("Close", (*) => myGui.Destroy())

        ThemeHelper.ApplyWindowTheme(myGui.Hwnd)
        myGui.Show("w560 AutoSize Center")
    }
}
