#Requires AutoHotkey v2.0

; ---------------------------------------------------------------------------
; WindowIcons
;
; Icon + application-name helpers for the window switcher.
;
; Icons are resolved in this order:
;   1. the icon the window itself exposes (WM_GETICON / window class icon)
;   2. the icon of the owning executable (shell or embedded resources)
;   3. a generic application icon
;
; Handles returned by GetIconForWindow are owned by the cache and must NOT be
; destroyed by the caller. They are reused across switcher sessions, which
; keeps repeated CapsLock + L invocations instant.
; ---------------------------------------------------------------------------

class WindowIcons {
    ; "hwnd|size" -> hIcon
    static _windowIcons := Map()
    ; "exePath|size" -> hIcon
    static _exeIcons := Map()
    ; exePath -> display name (FileDescription when available)
    static _names := Map()
    ; image list handle -> true
    static _lists := Map()

    static IMAGE_ICON        := 1
    static ILC_MASK          := 0x0001
    static ILC_COLOR32       := 0x0020

    static SHGFI_ICON        := 0x00000100
    static SHGFI_SMALLICON   := 0x00000001

    static WM_GETICON        := 0x007F
    static ICON_BIG          := 1
    static ICON_SMALL2       := 2
    static SMTO_ABORTIFHUNG  := 0x0002

    static LVM_SETIMAGELIST  := 0x1003
    static LVSIL_SMALL       := 1

    static CLR_NONE          := 0xFFFFFFFF

    ; Window icons are cached per window handle. Long sessions open and close
    ; many windows, so the cache is capped and recycled instead of growing
    ; forever. Image lists hold their own copies, so dropping the cache is safe.
    static MaxWindowIcons    := 256

    ; --- Public API --------------------------------------------------------

    ; Convert a logical icon size into a DPI-aware pixel size. Icon sizes feed
    ; a Win32 image list, which works in raw pixels rather than GUI units.
    static ScaleForDpi(size) {
        size := (size is Integer) ? size : 24
        dpi := A_ScreenDPI ? A_ScreenDPI : 96
        scaled := Round(size * dpi / 96)
        return Max(16, Min(scaled, 128))
    }

    ; Returns an HICON for a window entry, or 0 when nothing usable exists.
    ; "size" is expected in raw pixels (see ScaleForDpi).
    static GetIconForWindow(hwnd, exePath, size) {
        if !(size is Integer) || size <= 0
            size := 24

        if hwnd {
            key := hwnd "|" size
            if this._windowIcons.Has(key)
                return this._windowIcons[key]

            hIcon := this._FromWindow(hwnd, size)
            if !hIcon && exePath != ""
                hIcon := this._FromExecutable(exePath, size)
            if !hIcon
                hIcon := this._GenericIcon(size)

            if hIcon {
                if this._windowIcons.Count >= this.MaxWindowIcons
                    this._RecycleWindowIcons()
                this._windowIcons[key] := hIcon
                return hIcon
            }
        }

        if exePath != ""
            return this._FromExecutable(exePath, size)

        return this._GenericIcon(size)
    }

    static _RecycleWindowIcons() {
        for key, hIcon in this._windowIcons {
            if hIcon
                try DllCall("user32\DestroyIcon", "Ptr", hIcon)
        }
        this._windowIcons := Map()
    }

    ; Friendly application name: the executable's FileDescription when the
    ; binary exposes one, otherwise a tidied file name.
    static GetDisplayName(exePath, fallback := "") {
        if exePath == ""
            return fallback

        if this._names.Has(exePath)
            return this._names[exePath]

        name := ""
        try
            name := this._FileDescription(exePath)
        catch
            name := ""

        if name == "" {
            name := this._PrettyFileName(exePath)
            if name == ""
                name := fallback
        }

        if name != ""
            this._names[exePath] := name

        return name
    }

    ; --- Image list plumbing ----------------------------------------------

    static CreateImageList(size) {
        hList := 0
        try
            hList := DllCall(
                "comctl32\ImageList_Create",
                "Int",  size,
                "Int",  size,
                "UInt", this.ILC_COLOR32 | this.ILC_MASK,
                "Int",  16,
                "Int",  16,
                "Ptr"
            )
        catch
            return 0

        if hList
            this._lists[hList] := true

        return hList
    }

    ; Adds a copy of hIcon to the list and returns its zero-based index,
    ; or -1 on failure.
    static AddIcon(hList, hIcon) {
        if !hList || !hIcon
            return -1

        index := -1
        try
            index := DllCall(
                "comctl32\ImageList_AddIcon",
                "Ptr", hList,
                "Ptr", hIcon,
                "Int"
            )
        catch
            index := -1

        return (index is Integer) ? index : -1
    }

    ; Binds the image list to a ListView in report mode. The image list size
    ; also establishes the minimum row height, which is what makes icon size
    ; and row density feel connected.
    static AttachImageList(hList, lvHwnd) {
        if !hList || !lvHwnd
            return false

        try {
            SendMessage(
                this.LVM_SETIMAGELIST,
                this.LVSIL_SMALL,
                hList,
                ,
                "ahk_id " lvHwnd,
                ,
                ,
                ,
                200
            )
            return true
        } catch
            return false
    }

    static DestroyImageList(hList) {
        if !hList || !this._lists.Has(hList)
            return

        try
            DllCall("comctl32\ImageList_Destroy", "Ptr", hList)
        this._lists.Delete(hList)
    }

    ; --- Icon extraction ---------------------------------------------------

    static _FromWindow(hwnd, size) {
        hIcon := this._WindowIcon(hwnd, size)
        if hIcon
            return hIcon
        return this._ClassIcon(hwnd, size)
    }

    static _WindowIcon(hwnd, size) {
        result := Buffer(A_PtrSize, 0)

        for iconType in [this.ICON_SMALL2, this.ICON_BIG] {
            sent := 0
            try
                sent := DllCall(
                    "user32\SendMessageTimeoutW",
                    "Ptr",  hwnd,
                    "UInt", this.WM_GETICON,
                    "Ptr",  iconType,
                    "Ptr",  0,
                    "UInt", this.SMTO_ABORTIFHUNG,
                    "UInt", 40,
                    "Ptr",  result,
                    "Ptr"
                )
            catch
                continue

            if !sent
                continue

            h := NumGet(result, 0, "Ptr")
            if !h
                continue

            copy := this._Rescale(h, size)
            if copy
                return copy
        }

        return 0
    }

    static _ClassIcon(hwnd, size) {
        for index in [-14, -34] {   ; GCLP_HICON, GCLP_HICONSM
            h := 0
            try
                h := DllCall(
                    "user32\GetClassLongPtr",
                    "Ptr", hwnd,
                    "Int", index,
                    "Ptr"
                )
            catch
                continue

            if !h
                continue

            copy := this._Rescale(h, size)
            if copy
                return copy
        }

        return 0
    }

    static _FromExecutable(exePath, size) {
        key := exePath "|" size
        if this._exeIcons.Has(key)
            return this._exeIcons[key]

        hIcon := this._ShellIcon(exePath, size)
        if !hIcon
            hIcon := this._ExtractedIcon(exePath, size)

        if hIcon
            this._exeIcons[key] := hIcon

        return hIcon
    }

    ; Ask the shell for the icon associated with the file. The shell returns
    ; its native small (16) or large (32) variant, so the result is rescaled
    ; for intermediate sizes such as 20 or 24.
    static _ShellIcon(exePath, size) {
        flags := this.SHGFI_ICON
        if size <= 20
            flags |= this.SHGFI_SMALLICON

        ; SHFILEINFOW: HICON, int, DWORD, WCHAR[260], WCHAR[80]
        info := Buffer(A_PtrSize + 4 + 4 + (260 * 2) + (80 * 2), 0)

        ok := 0
        try
            ok := DllCall(
                "shell32\SHGetFileInfoW",
                "WStr", exePath,
                "UInt", 0,
                "Ptr",  info,
                "UInt", info.Size,
                "UInt", flags,
                "Ptr"
            )
        catch
            return 0

        if !ok
            return 0

        h := NumGet(info, 0, "Ptr")
        if !h
            return 0

        copy := this._Rescale(h, size)
        ; SHGetFileInfo hands back an icon the caller owns.
        try
            DllCall("user32\DestroyIcon", "Ptr", h)

        return copy
    }

    ; Fallback path for files the shell cannot resolve: read the icon straight
    ; out of the executable's resource section.
    static _ExtractedIcon(exePath, size) {
        handles := Buffer(A_PtrSize * 2, 0)
        count := 0

        try
            count := DllCall(
                "shell32\ExtractIconExW",
                "WStr", exePath,
                "Int",  0,
                "Ptr",  handles,
                "Ptr",  handles.Ptr + A_PtrSize,
                "UInt", 1,
                "UInt"
            )
        catch
            return 0

        if !count
            return 0

        hLarge := NumGet(handles, 0, "Ptr")
        hSmall := NumGet(handles, A_PtrSize, "Ptr")

        source := 0
        if size <= 20 && hSmall
            source := hSmall
        else if hLarge
            source := hLarge
        else if hSmall
            source := hSmall

        copy := this._Rescale(source, size)

        if hLarge
            try DllCall("user32\DestroyIcon", "Ptr", hLarge)
        if hSmall
            try DllCall("user32\DestroyIcon", "Ptr", hSmall)

        return copy
    }

    ; Windows without a resolvable icon still get a neutral placeholder so the
    ; row keeps its alignment instead of collapsing to bare text.
    static _GenericIcon(size) {
        h := 0
        try
            h := DllCall(
                "user32\LoadIcon",
                "Ptr", 0,
                "Ptr", 32512,   ; IDI_APPLICATION
                "Ptr"
            )
        catch
            return 0

        if !h
            return 0

        ; Shared system icon: copy it, never destroy the original.
        return this._Rescale(h, size)
    }

    ; CopyImage always produces an icon this cache owns, which keeps ownership
    ; rules simple regardless of where the source icon came from.
    static _Rescale(hIcon, size) {
        if !hIcon
            return 0

        copy := 0
        try
            copy := DllCall(
                "user32\CopyImage",
                "Ptr",  hIcon,
                "UInt", this.IMAGE_ICON,
                "Int",  size,
                "Int",  size,
                "UInt", 0,
                "Ptr"
            )
        catch
            return 0

        return copy
    }

    ; --- File description (application display name) -----------------------

    static _FileDescription(exePath) {
        if !FileExist(exePath)
            return ""

        size := 0
        try
            size := DllCall(
                "version\GetFileVersionInfoSizeW",
                "WStr", exePath,
                "Ptr",  0,
                "UInt"
            )
        catch
            return ""

        if size <= 0 || size > 10000000
            return ""

        data := Buffer(size, 0)

        ok := false
        try
            ok := DllCall(
                "version\GetFileVersionInfoW",
                "WStr", exePath,
                "UInt", 0,
                "UInt", size,
                "Ptr",  data,
                "UInt"
            )
        catch
            return ""

        if !ok
            return ""

        block := "\StringFileInfo\040904B0\FileDescription"

        ptrBuf := Buffer(A_PtrSize, 0)
        lenBuf := Buffer(4, 0)

        found := false
        try
            found := DllCall(
                "version\VerQueryValueW",
                "Ptr",  data,
                "WStr", "\VarFileInfo\Translation",
                "Ptr",  ptrBuf,
                "Ptr",  lenBuf,
                "UInt"
            )
        catch
            found := false

        if found {
            ptr := NumGet(ptrBuf, 0, "Ptr")
            len := NumGet(lenBuf, 0, "UInt")
            if ptr && len >= 4 {
                lang := NumGet(ptr, 0, "UShort")
                code := NumGet(ptr, 2, "UShort")
                block := Format(
                    "\StringFileInfo\{:04X}{:04X}\FileDescription",
                    lang,
                    code
                )
            }
        }

        for candidate in [
            block,
            "\StringFileInfo\040904B0\FileDescription",
            "\StringFileInfo\040904E4\FileDescription"
        ] {
            NumPut("Ptr", 0, ptrBuf, 0)
            NumPut("UInt", 0, lenBuf, 0)

            resolved := false
            try
                resolved := DllCall(
                    "version\VerQueryValueW",
                    "Ptr",  data,
                    "WStr", candidate,
                    "Ptr",  ptrBuf,
                    "Ptr",  lenBuf,
                    "UInt"
                )
            catch
                continue

            if !resolved
                continue

            ptr := NumGet(ptrBuf, 0, "Ptr")
            len := NumGet(lenBuf, 0, "UInt")

            if !ptr || len <= 0
                continue

            text := ""
            try
                text := Trim(StrGet(ptr, len, "UTF-16"))
            catch
                continue

            if text != ""
                return text
        }

        return ""
    }

    static _PrettyFileName(exePath) {
        parts := StrSplit(exePath, "\")
        base := parts.Length ? parts[parts.Length] : exePath
        base := RegExReplace(base, "i)\.exe$", "")
        return Trim(base)
    }
}
