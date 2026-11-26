#Requires AutoHotkey v2.0

class FileDeleter {
    static Busy := false
    static OperationFlags := 0x00000400 | 0x00000010 | 0x00000004

    static IsFileBrowserActive(windowHwnd := 0) {
        if !windowHwnd
            windowHwnd := WinExist("A")
        if !windowHwnd
            return false
        try {
            cls := WinGetClass("ahk_id " windowHwnd)
            if cls == "CabinetWClass"
                return this._HasShellViewFocus(windowHwnd)
            if cls == "Progman" || cls == "WorkerW"
                return ControlGetHwnd("SHELLDLL_DefView", "ahk_id " windowHwnd) != 0
        }
        return false
    }

    static _HasShellViewFocus(windowHwnd) {
        try {
            focused := ControlGetFocus("ahk_id " windowHwnd)
            return InStr(focused, "DirectUIHWND") || InStr(focused, "SysListView32")
        }
        return false
    }

    static ConfirmDelete() {
        if this.Busy
            return
        this.Busy := true
        try {
            paths := this.GetSelectedFiles()
            if paths.Length == 0 {
                ShowToolTip(Lang("MSG_FILE_DELETE_NONE"), 1800)
                return
            }
            if !this._ConfirmPaths(paths)
                return
            success := this.DeletePaths(paths)
            remaining := false
            for path in paths {
                if FileExist(path) {
                    remaining := true
                    break
                }
            }
            message := (success && !remaining)
                ? Lang("MSG_FILE_DELETE_DONE", "", paths.Length)
                : Lang("MSG_FILE_DELETE_FAIL")
            ShowToolTip(message, 2500)
        } finally {
            this.Busy := false
        }
    }

    static _ConfirmPaths(paths) {
        result := {confirmed: false, closed: false}
        dialog := Gui("+AlwaysOnTop -MaximizeBox -MinimizeBox", Lang("GUI_FILE_DELETE_TITLE"))
        ThemeHelper.StyleGui(dialog)
        ThemeHelper.AddTitle(dialog, Lang("GUI_FILE_DELETE_TITLE"), 530)
        dialog.Add("Text", "x18 y+12 w530", Lang("MSG_FILE_DELETE_CONFIRM", "", paths.Length))
        dialog.Add("ListBox", "x18 y+12 w530 r8", paths)
        confirm := ThemeHelper.AddButton(dialog, "x310 y+16 w112 h32", Lang("FILE_DELETE_CONFIRM"), "danger")
        cancel := ThemeHelper.AddButton(dialog, "Default x+12 yp w112 h32", Lang("GUI_CANCEL"))
        confirm.OnEvent("Click", (*) => Finish(true))
        cancel.OnEvent("Click", (*) => Finish(false))
        dialog.OnEvent("Escape", (*) => Finish(false))
        dialog.OnEvent("Close", (*) => Finish(false))
        ThemeHelper.ApplyWindowTheme(dialog.Hwnd)
        dialog.Show("w566 AutoSize Center")
        cancel.Focus()
        try {
            while !result.closed
                Sleep(20)
        } finally {
            dialog.Destroy()
        }
        return result.confirmed

        Finish(confirmed) {
            result.confirmed := confirmed
            result.closed := true
        }
    }

    static GetSelectedFiles(windowHwnd := 0) {
        if !windowHwnd
            windowHwnd := WinExist("A")
        if !this.IsFileBrowserActive(windowHwnd)
            return []
        try {
            view := this._GetFolderView(windowHwnd)
            paths := []
            for item in view.SelectedItems() {
                if item.IsFileSystem && FileExist(item.Path)
                    paths.Push(item.Path)
            }
            return paths
        }
        return []
    }

    static _GetFolderView(windowHwnd) {
        shell := ComObject("Shell.Application")
        if WinGetClass("ahk_id " windowHwnd) != "CabinetWClass" {
            handle := Buffer(4, 0)
            desktop := shell.Windows.FindWindowSW(0, 0, 8, ComValue(0x4003, handle.Ptr), 1)
            return desktop.Document
        }
        for window in shell.Windows {
            if window.HWND != windowHwnd
                continue
            return window.Document
        }
        throw Error("No active Shell view")
    }

    static _Guid(text) {
        guid := Buffer(16)
        DllCall("ole32\CLSIDFromString", "WStr", text, "Ptr", guid, "HRESULT")
        return guid
    }

    static DeletePaths(paths) {
        if !(paths is Array) || paths.Length == 0
            return false
        try {
            operation := ComObject("{3AD05575-8857-4850-9277-11B85BDB8E09}",
                "{947AAB5F-0A5C-4C13-B4D6-4BF7836FC9F8}")
            ComCall(5, operation, "UInt", this.OperationFlags)
            for path in paths
                this._QueueDeletion(operation, path)
            ComCall(21, operation)
            ; IFileOperationVtbl: IUnknown (0-2), then the 20 interface methods.
            ; GetAnyOperationsAborted is the last one, i.e. slot 22.
            ComCall(22, operation, "Int*", &aborted := 0)
            return !aborted
        }
        return false
    }

    static _QueueDeletion(operation, path) {
        if !RegExMatch(path, "i)^(?:[a-z]:\\.+|\\\\[^\\]+\\[^\\]+\\.+)$")
            throw ValueError("Expected an absolute file or folder path")
        itemId := this._Guid("{43826D1E-E718-42EE-BC55-A1E261C37BFE}")
        DllCall("shell32\SHCreateItemFromParsingName", "WStr", path, "Ptr", 0,
            "Ptr", itemId, "Ptr*", &itemPtr := 0, "HRESULT")
        item := ComValue(13, itemPtr, 1)
        ComCall(18, operation, "Ptr", item, "Ptr", 0)
    }
}
