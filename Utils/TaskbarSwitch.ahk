#Requires AutoHotkey v2.0

class TaskbarSwitch {
    ; Keep Windows responsible for taskbar ordering, while using the same
    ; taskbar button to cycle windows inside a grouped application.
    ;
    ; E:
    ;   1. Continue cycling the current taskbar group when possible.
    ;   2. When the group is exhausted (or there is only one window), use Win+T
    ;      to move to the next taskbar application.
    ;
    ; Q:
    ;   1. Walk back through windows already observed in the current group.
    ;   2. When leaving that group, use Win+Shift+T for the previous app.
    ;
    ; The taskbar button is located through Windows UI Automation rather than
    ; by maintaining our own taskbar/window ordering.

    static _button := 0
    static _groupWindows := []
    static _groupIndex := 0
    static _groupStartHwnd := 0
    static _lastActiveHwnd := 0

    static Next() {
        currentHwnd := WinExist("A")

        ; If the user switched windows outside CapsLock- since the last call,
        ; the saved taskbar button/history is no longer trustworthy.
        if currentHwnd != this._lastActiveHwnd {
            this._ResetState()
        }

        if this._button && this._lastActiveHwnd {
            nextHwnd := this._CtrlClickButton()
            if nextHwnd {
                if nextHwnd == this._groupStartHwnd {
                    ; We completed a full cycle of the current group. Move on
                    ; to the next taskbar application instead of repeating it.
                    this._ResetState()
                    this._MoveToNextTaskbarApp()
                } else {
                    this._RememberGroupWindow(nextHwnd)
                }
                return
            }
        }

        this._MoveToNextTaskbarApp()
    }

    static Prev() {
        currentHwnd := WinExist("A")

        ; Group history is meaningful only while our own navigation still
        ; points at the active window. Manual switching starts a new sequence.
        if currentHwnd != this._lastActiveHwnd {
            this._ResetState()
        }

        if this._groupWindows.Length {
            if this._groupIndex > 1 {
                this._groupIndex -= 1
                targetHwnd := this._groupWindows[this._groupIndex]
                if targetHwnd && WinExist("ahk_id " targetHwnd) {
                    WinActivate("ahk_id " targetHwnd)
                    this._lastActiveHwnd := targetHwnd
                    return
                }
                this._ResetState()
            } else if this._groupIndex == 1 {
                ; We are at the first observed window of the group. Continue
                ; to the previous taskbar application via Windows itself.
                this._ResetState()
            }
        }

        this._MoveToPreviousTaskbarApp()
    }

    static _MoveToNextTaskbarApp() {
        this._ReleasePhysicalShift()

        try {
            SendEvent("#{t}")
            Sleep(35)

            button := this._GetFocusedTaskbarButton()
            if !button {
                ; UI Automation can be unavailable in unusual shell states.
                ; Enter still activates the taskbar item selected by Win+T.
                SendEvent("{Enter}")
                this._lastActiveHwnd := WinExist("A")
                return
            }

            this._button := button
            targetHwnd := this._CtrlClickButton()
            if targetHwnd {
                this._groupWindows := [targetHwnd]
                this._groupIndex := 1
                this._groupStartHwnd := targetHwnd
                this._lastActiveHwnd := targetHwnd
            } else {
                SendEvent("{Enter}")
                this._groupWindows := []
                this._groupIndex := 0
                this._groupStartHwnd := 0
                this._lastActiveHwnd := WinExist("A")
            }
        } finally {
            this._RestorePhysicalShift()
        }
    }

    static _MoveToPreviousTaskbarApp() {
        this._ReleasePhysicalShift()

        try {
            SendEvent("#+{t}")
            Sleep(35)
            this._lastActiveHwnd := WinExist("A")
        } finally {
            this._RestorePhysicalShift()
        }
    }

    static _CtrlClickButton() {
        if !this._button
            return 0

        x := this._button.x + (this._button.w // 2)
        y := this._button.y + (this._button.h // 2)
        if this._button.w <= 4 || this._button.h <= 4
            return 0

        MouseGetPos(&oldX, &oldY)
        try {
            CoordMode("Mouse", "Screen")
            MouseMove(x, y, 0)
            SendEvent("{Ctrl down}")
            Click()
            SendEvent("{Ctrl up}")
            Sleep(40)
            return WinExist("A")
        } catch {
            try SendEvent("{Ctrl up}")
            return 0
        } finally {
            MouseMove(oldX, oldY, 0)
        }
    }

    static _GetFocusedTaskbarButton() {
        static uia := ComObject(
            "{FF48DBA4-60EF-4201-AA87-54103EEF594E}",
            "{30CBE57D-D9D0-452A-AB13-7AC5AC4825EE}"
        )

        try {
            elementPtr := 0
            if ComCall(8, uia, "ptr*", &elementPtr) != 0 || !elementPtr
                return 0

            element := ComValue(13, elementPtr)
            rect := Buffer(16, 0)
            if ComCall(43, element, "ptr", rect) != 0
                return 0

            left := NumGet(rect, 0, "Int")
            top := NumGet(rect, 4, "Int")
            right := NumGet(rect, 8, "Int")
            bottom := NumGet(rect, 12, "Int")
            width := right - left
            height := bottom - top

            if width <= 4 || height <= 4
                return 0

            return { x: left, y: top, w: width, h: height }
        } catch {
            return 0
        }
    }

    static _RememberGroupWindow(hwnd) {
        if !hwnd
            return

        for index, existingHwnd in this._groupWindows {
            if existingHwnd == hwnd {
                this._groupIndex := index
                this._lastActiveHwnd := hwnd
                return
            }
        }

        this._groupWindows.Push(hwnd)
        this._groupIndex := this._groupWindows.Length
        this._lastActiveHwnd := hwnd
    }

    static _ResetState() {
        this._button := 0
        this._groupWindows := []
        this._groupIndex := 0
        this._groupStartHwnd := 0
        this._lastActiveHwnd := 0
    }

    static _ReleasePhysicalShift() {
        this._leftShiftWasDown := GetKeyState("LShift", "P")
        this._rightShiftWasDown := GetKeyState("RShift", "P")

        if this._leftShiftWasDown
            SendEvent("{LShift up}")
        if this._rightShiftWasDown
            SendEvent("{RShift up}")
    }

    static _RestorePhysicalShift() {
        if this._leftShiftWasDown
            SendEvent("{LShift down}")
        if this._rightShiftWasDown
            SendEvent("{RShift down}")
    }
}
