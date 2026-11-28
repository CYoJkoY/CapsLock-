#Requires AutoHotkey v2.0

class FileDeleter {
    static Busy := false
    ; Flags for the IFileOperation *fallback* only: no undo (permanent), no
    ; confirmation dialog, no error UI. The fast path below deletes through
    ; the kernel directly and does not consult them.
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

    ; --- Native deletion constants ------------------------------------------
    ; IFileOperation queues one shell item per path, and building that item
    ; (SHCreateItemFromParsingName) costs ~3ms per file: a 300-file selection
    ; spends about one second before the operation even starts. Talking to the
    ; filesystem directly removes that per-item cost entirely.
    static INVALID_FILE_ATTRIBUTES := 0xFFFFFFFF
    static FILE_ATTRIBUTE_READONLY := 0x00000001
    static FILE_ATTRIBUTE_DIRECTORY := 0x00000010
    static FILE_ATTRIBUTE_REPARSE_POINT := 0x00000400
    static DELETE_ACCESS := 0x00010000
    static SHARE_ALL := 0x00000007
    static OPEN_EXISTING := 3
    static FILE_FLAG_BACKUP_SEMANTICS := 0x02000000
    static FILE_FLAG_OPEN_REPARSE_POINT := 0x00200000
    ; FileDispositionInformationEx, i.e. FILE_INFORMATION_CLASS value 64.
    static DispositionInformationEx := 64
    ; FILE_DISPOSITION_FLAG_DELETE | _POSIX_SEMANTICS | _IGNORE_READONLY_ATTRIBUTE.
    ; POSIX semantics unlinks the name immediately instead of deferring until
    ; the last handle closes, and the read-only bit no longer needs clearing.
    static DispositionFlags := 0x00000001 | 0x00000002 | 0x00000010
    static WIN32_FIND_DATAW_SIZE := 592
    static WIN32_FIND_NAME_OFFSET := 44

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
        pathList := dialog.Add(
            "ListBox",
            "x18 y+12 w530 r8 c" Theme.Text " Background" Theme.Control,
            paths
        )
        ThemeHelper._SetWindowTheme(pathList.Hwnd, ThemeHelper.ThemeClass("explorer"))
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
        for path in paths
            if !this._IsDeletablePath(path)
                return false

        ; Fast path: kernel deletion. Items that refuse to go this way (cloud
        ; placeholder files, third-party filter drivers, some virtual folders)
        ; are collected and retried through the shell, which knows about them.
        remaining := []
        for path in paths {
            if !FileExist(path)
                continue
            if this._DeleteNative(path)
                continue
            remaining.Push(path)
        }
        if remaining.Length
            this._DeleteShell(remaining)

        for path in paths
            if FileExist(path)
                return false
        return true
    }

    ; Accept absolute filesystem paths only, and never a volume or share root:
    ; those are selection mistakes rather than something to delete.
    static _IsDeletablePath(path) {
        if !(path is String) || path == ""
            return false
        if !RegExMatch(path, "i)^(?:[a-z]:\\|\\\\)")
            return false
        trimmed := RTrim(path, "\")
        if trimmed == ""
            return false
        if RegExMatch(trimmed, "i)^[a-z]:$")
            return false
        if RegExMatch(trimmed, "^\\\\[^\\\\]+$")
            return false
        if RegExMatch(trimmed, "^\\\\[^\\\\]+\\[^\\\\]+$")
            return false
        return true
    }

    ; \??\ style prefix that lets every Win32 call below address paths beyond
    ; MAX_PATH without depending on the process-wide long-path opt-in.
    static _ExtendedPath(path) {
        if SubStr(path, 1, 4) == "\\?\"
            return path
        if SubStr(path, 1, 2) == "\\"
            return "\\?\UNC\" SubStr(path, 3)
        return "\\?\" path
    }

    static _Join(dir, name) {
        return SubStr(dir, -1) == "\" ? dir name : dir "\" name
    }

    static _Exists(extPath) {
        return DllCall("GetFileAttributesW", "WStr", extPath, "UInt")
            != this.INVALID_FILE_ATTRIBUTES
    }

    ; True when the entry is gone afterwards, whether by our own call or
    ; because it disappeared in the meantime.
    static _DeleteNative(path) {
        extPath := this._ExtendedPath(path)
        attr := DllCall("GetFileAttributesW", "WStr", extPath, "UInt")
        if (attr == this.INVALID_FILE_ATTRIBUTES)
            return true
        ; One POSIX delete covers plain files, empty folders, symlinks and
        ; junctions, and ignores the read-only bit on the way out.
        if this._PosixDelete(extPath)
            return true
        if (attr & this.FILE_ATTRIBUTE_DIRECTORY) {
            ; A link is removed, never followed: only the reparse point goes.
            if (attr & this.FILE_ATTRIBUTE_REPARSE_POINT)
                return this._RemoveDirectory(extPath, attr)
            this._DeleteTree(extPath, attr)
            return !this._Exists(extPath)
        }
        return this._DeleteFile(extPath, attr)
    }

    ; NtSetInformationFile(FileDispositionInformationEx) with POSIX semantics:
    ; the name is unlinked in one call, no shell item, no progress dialog.
    static _PosixDelete(extPath, flags := 0) {
        if (flags == 0)
            flags := this.DispositionFlags
        handle := DllCall("CreateFileW", "WStr", extPath,
            "UInt", this.DELETE_ACCESS, "UInt", this.SHARE_ALL, "Ptr", 0,
            "UInt", this.OPEN_EXISTING,
            "UInt", this.FILE_FLAG_BACKUP_SEMANTICS | this.FILE_FLAG_OPEN_REPARSE_POINT,
            "Ptr", 0, "Ptr")
        if (handle == -1 || handle == 0)
            return false
        info := Buffer(4, 0)
        NumPut("UInt", flags, info)
        ioStatus := Buffer(16, 0)
        status := DllCall("ntdll\NtSetInformationFile", "Ptr", handle, "Ptr", ioStatus,
            "Ptr", info, "UInt", info.Size, "Int", this.DispositionInformationEx, "Int")
        DllCall("CloseHandle", "Ptr", handle)
        return status == 0
    }

    static _DeleteFile(extPath, attr) {
        if (attr & this.FILE_ATTRIBUTE_READONLY)
            this._ClearReadOnly(extPath)
        if DllCall("DeleteFileW", "WStr", extPath, "Int")
            return true
        return !this._Exists(extPath)
    }

    static _RemoveDirectory(extPath, attr) {
        if DllCall("RemoveDirectoryW", "WStr", extPath, "Int")
            return true
        if (attr & this.FILE_ATTRIBUTE_READONLY) {
            this._ClearReadOnly(extPath)
            if DllCall("RemoveDirectoryW", "WStr", extPath, "Int")
                return true
        }
        return !this._Exists(extPath)
    }

    static _ClearReadOnly(extPath) {
        attr := DllCall("GetFileAttributesW", "WStr", extPath, "UInt")
        if (attr == this.INVALID_FILE_ATTRIBUTES)
            return
        DllCall("SetFileAttributesW", "WStr", extPath,
            "UInt", attr & ~this.FILE_ATTRIBUTE_READONLY)
    }

    ; Depth-first walk with FindFirstFileW. Recursing here costs about 0.03ms
    ; per entry, roughly ten times less than AutoHotkey's own recursive
    ; DirDelete and far less than queuing every entry through the shell.
    static _DeleteTree(extDir, dirAttr) {
        findData := Buffer(this.WIN32_FIND_DATAW_SIZE, 0)
        handle := DllCall("FindFirstFileW", "WStr", this._Join(extDir, "*"),
            "Ptr", findData, "Ptr")
        if (handle != -1) {
            try {
                loop {
                    name := StrGet(findData.Ptr + this.WIN32_FIND_NAME_OFFSET, "UTF-16")
                    if (name != "." && name != "..") {
                        child := this._Join(extDir, name)
                        attr := NumGet(findData.Ptr, 0, "UInt")
                        if !this._PosixDelete(child) {
                            if (attr & this.FILE_ATTRIBUTE_DIRECTORY) {
                                if (attr & this.FILE_ATTRIBUTE_REPARSE_POINT)
                                    this._RemoveDirectory(child, attr)
                                else
                                    this._DeleteTree(child, attr)
                            } else
                                this._DeleteFile(child, attr)
                        }
                    }
                    if !DllCall("FindNextFileW", "Ptr", handle, "Ptr", findData, "Int")
                        break
                }
            } finally {
                DllCall("FindClose", "Ptr", handle)
            }
        }
        this._RemoveDirectory(extDir, dirAttr)
    }

    ; Shell fallback for entries the kernel path could not remove: cloud
    ; placeholder files, items held by a filter driver, or virtual folders.
    ; Slower (one shell item per path) but it understands those namespaces.
    static _DeleteShell(paths) {
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
