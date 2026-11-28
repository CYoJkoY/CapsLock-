#Requires AutoHotkey v2.0

class FileDeleter {
    static Busy := false
    static OperationFlags := 0x00000400 | 0x00000010 | 0x00000004
    static ExplorerWindowClass := "CabinetWClass"
    static DesktopWindowClass := "Progman"
    static DesktopFallbackClass := "WorkerW"
    static ShellViewClass := "SHELLDLL_DefView"
    static ShellViewControl := "SHELLDLL_DefView1"
    ; Windows 11 hosts the address bar, the search box and the inline rename
    ; editor in this class instead of a plain Edit. Focus on it therefore means
    ; "the user is typing", not "the file list is active".
    static ExplorerTextInputClasses := ["InputSiteWindowClass"]

    static IsFileBrowserActive(windowHwnd := 0) {
        if !windowHwnd
            windowHwnd := WinExist("A")
        if !windowHwnd
            return false
        try {
            cls := WinGetClass("ahk_id " windowHwnd)
            ; In an Explorer window the file listing usually owns focus, so the
            ; shortcut means "permanently delete the selected files". The
            ; address bar, the search box and inline renaming are text inputs,
            ; where the same key has to keep deleting the next word instead.
            if cls == this.ExplorerWindowClass
                return !this._FocusedControlIsTextInput(windowHwnd)
            if cls == this.DesktopWindowClass || cls == this.DesktopFallbackClass
                return this._DesktopHasShellView(windowHwnd)
        }
        return false
    }

    ; Resolve the focused control of windowHwnd to a Win32 class name.
    ;
    ; ControlGetFocus returns the control's HWND in this AutoHotkey build, so
    ; the old code compared an integer against a class name and always failed -
    ; that was why the delete shortcut stopped working in Explorer. A ClassNN
    ; string ("DirectUIHWND3") is accepted too, keeping the check independent of
    ; the return type.
    static _FocusedControlClass(windowHwnd) {
        focused := 0
        try focused := ControlGetFocus("ahk_id " windowHwnd)
        catch
            return ""
        if !focused
            return ""
        if IsInteger(focused) {
            try return WinGetClass("ahk_id " focused)
            catch
                return ""
        }
        text := String(focused)
        if RegExMatch(text, "^\d+$") {
            try return WinGetClass("ahk_id " Integer(text))
            catch
                return ""
        }
        return text
    }

    static _FocusedControlIsTextInput(windowHwnd) {
        return this._IsTextInputClassValue(this._FocusedControlClass(windowHwnd))
    }

    ; True when a class name with an optional ClassNN instance suffix names a
    ; text input. "Edit1" and "Edit" both qualify; a shell-view ClassNN such as
    ; "SysListView322" does not, because the stripped name is not a text input.
    ; Explorer-specific input hosts are included, so the address bar, the search
    ; box and inline renaming keep the text-editing meaning of the shortcut.
    static _IsTextInputClassValue(classValue) {
        if classValue == ""
            return false
        if IsTextInputControlClass(classValue)
            return true
        stripped := RegExReplace(classValue, "\d+$")
        if stripped == ""
            return false
        if IsTextInputControlClass(stripped)
            return true
        for knownClass in this.ExplorerTextInputClasses
            if StrLower(stripped) == StrLower(knownClass)
                return true
        return false
    }

    static _DesktopHasShellView(windowHwnd) {
        try {
            controls := WinGetControls("ahk_id " windowHwnd)
        } catch {
            controls := []
        }
        for control in controls
            if RegExMatch(control, "i)^" this.ShellViewClass)
                return true
        try
            return ControlGetHwnd(this.ShellViewControl, "ahk_id " windowHwnd) != 0
        catch
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
