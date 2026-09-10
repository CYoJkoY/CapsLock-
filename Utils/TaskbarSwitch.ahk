#Requires AutoHotkey v2.0

class TaskbarSwitch {
    ; Use Windows' native Alt+Tab switcher instead of maintaining our own
    ; window list. This keeps switching consistent with the OS MRU order,
    ; virtual desktops, minimized windows, and multi-window applications.
    static Next() {
        this._SendAltTab(false)
    }

    static Prev() {
        this._SendAltTab(true)
    }

    static _SendAltTab(reverse) {
        leftShift := GetKeyState("LShift", "P")
        rightShift := GetKeyState("RShift", "P")

        ; The +Q/+E hotkeys physically hold Shift. Release it temporarily so
        ; the generated shortcut is explicit rather than inheriting hotkey state.
        if leftShift
            SendEvent("{LShift up}")
        if rightShift
            SendEvent("{RShift up}")

        try {
            if reverse
                SendEvent("{Alt down}{Shift down}{Tab}{Shift up}{Alt up}")
            else
                SendEvent("{Alt down}{Tab}{Alt up}")
        } finally {
            if leftShift
                SendEvent("{LShift down}")
            if rightShift
                SendEvent("{RShift down}")
        }
    }
}
