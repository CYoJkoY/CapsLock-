#Requires AutoHotkey v2.0

class TaskbarSwitch {
    ; Use Windows' native Alt+Tab switcher instead of maintaining our own
    ; window list. This keeps switching consistent with the OS MRU order,
    ; virtual desktops, minimized windows, and multi-window applications.
    static Next() {
        this._SendAltTab(false)
    }

    static Prev() {
        ; The +Q hotkey already holds Shift, so Alt+Tab naturally becomes
        ; Alt+Shift+Tab here and selects the previous MRU window.
        this._SendAltTab(true)
    }

    static _SendAltTab(reverse) {
        leftShift := GetKeyState("LShift", "P")
        rightShift := GetKeyState("RShift", "P")

        ; +E should invoke plain Alt+Tab. Temporarily release the physical
        ; Shift key(s) so Windows does not interpret it as Alt+Shift+Tab.
        if !reverse {
            if leftShift
                SendEvent("{LShift up}")
            if rightShift
                SendEvent("{RShift up}")
        }

        try {
            SendEvent("{Alt down}{Tab}{Alt up}")
        } finally {
            if !reverse {
                if leftShift
                    SendEvent("{LShift down}")
                if rightShift
                    SendEvent("{RShift down}")
            }
        }
    }
}
