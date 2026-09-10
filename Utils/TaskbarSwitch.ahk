#Requires AutoHotkey v2.0

class TaskbarSwitch {
    ; Use the Windows taskbar itself as the source of truth.
    ;
    ; 1. Resolve the active window to its AppUserModelID.
    ; 2. Resolve taskbar buttons through the same AppUserModelID.
    ; 3. Move to the adjacent taskbar button for cross-app navigation.
    ; 4. Use the native Ctrl+Click taskbar behavior for grouped windows.
    ;
    ; This deliberately avoids Win+T + Enter because Win+T focus is not a
    ; stable cursor after activation; blindly pressing Enter can reactivate
    ; the wrong pinned item or launch another instance.

    static _taskbarButtons := []
    static _currentAppId := ""
    static _currentTaskbarIndex := 0
    static _groupWindows := []
    static _groupIndex := 0
    static _lastActiveHwnd := 0

    static Next() {
        currentHwnd := WinExist("A")
        if !currentHwnd
            return

        this._ResetIfExternalSwitch(currentHwnd)

        appId := this._GetAppUserModelId(currentHwnd)
        if !appId
            appId := this._GetProcessFallbackId(currentHwnd)

        buttons := this._GetTaskbarButtons()
        if !buttons.Length {
            this._FallbackNext()
            return
        }

        currentIndex := this._FindButtonForApp(buttons, appId)
        if !currentIndex {
            this._FallbackNext()
            return
        }

        currentButton := buttons[currentIndex]

        ; If the taskbar represents several windows with this button, use the
        ; native Ctrl+Click cycle. A different HWND means we stayed in the same
        ; taskbar group, while returning to the original HWND means the group is
        ; exhausted and we should advance to the next app button.
        targetHwnd := this._CtrlClickButton(currentButton)
        if targetHwnd && targetHwnd != currentHwnd {
            this._currentAppId := appId
            this._currentTaskbarIndex := currentIndex
            this._RememberGroupWindow(targetHwnd)
            return
        }

        ; Single-window app or completed group: select the next taskbar app.
        nextIndex := this._AdjacentIndex(buttons.Length, currentIndex, true)
        this._ActivateTaskbarButton(buttons[nextIndex])
        this._SetNavigationState(buttons[nextIndex], nextIndex)
    }

    static Prev() {
        currentHwnd := WinExist("A")
        if !currentHwnd
            return

        this._ResetIfExternalSwitch(currentHwnd)

        ; Q is reverse navigation. Windows has no native reverse grouped-window
        ; shortcut, so use the short-lived forward-cycle history when available.
        if this._groupWindows.Length && this._groupIndex > 1 {
            targetHwnd := this._groupWindows[this._groupIndex - 1]
            if targetHwnd && WinExist("ahk_id " targetHwnd) {
                WinActivate("ahk_id " targetHwnd)
                this._groupIndex -= 1
                this._lastActiveHwnd := targetHwnd
                return
            }
            this._ResetState()
        }

        appId := this._GetAppUserModelId(currentHwnd)
        if !appId
            appId := this._GetProcessFallbackId(currentHwnd)

        buttons := this._GetTaskbarButtons()
        if !buttons.Length {
            this._FallbackPrev()
            return
        }

        currentIndex := this._FindButtonForApp(buttons, appId)
        if !currentIndex {
            this._FallbackPrev()
            return
        }

        currentButton := buttons[currentIndex]

        ; At the first known member of a group, probe forward until Explorer
        ; cycles back to the starting HWND. The last member visited is therefore
        ; the previous window in the taskbar's group order.
        if this._IsGroupedCandidate(currentButton) {
            previousHwnd := this._FindPreviousGroupedWindow(currentButton, currentHwnd)
            if previousHwnd {
                WinActivate("ahk_id " previousHwnd)
                this._lastActiveHwnd := previousHwnd
                return
            }
        }

        prevIndex := this._AdjacentIndex(buttons.Length, currentIndex, false)
        this._ActivateTaskbarButton(buttons[prevIndex])
        this._SetNavigationState(buttons[prevIndex], prevIndex)
    }

    static _FindPreviousGroupedWindow(button, startHwnd) {
        discovered := [startHwnd]
        previousHwnd := 0

        Loop 64 {
            targetHwnd := this._CtrlClickButton(button)
            if !targetHwnd
                return 0

            if targetHwnd == startHwnd {
                if !previousHwnd
                    return 0

                this._groupWindows := discovered
                this._groupIndex := discovered.Length
                this._lastActiveHwnd := startHwnd
                return previousHwnd
            }

            if !this._ContainsHwnd(discovered, targetHwnd)
                discovered.Push(targetHwnd)
            previousHwnd := targetHwnd
        }

        return 0
    }

    static _IsGroupedCandidate(button) {
        ; The taskbar's automation name commonly contains a running-window
        ; count, but this is only an optimization. Ctrl+Click remains the final
        ; authority because Windows owns the grouping rules.
        return InStr(StrLower(button.name), "running window") || InStr(StrLower(button.name), "windows")
    }

    static _GetTaskbarButtons() {
        buttons := []

        for taskbarClass in ["Shell_TrayWnd", "Shell_SecondaryTrayWnd"] {
            for trayHwnd in WinGetList("ahk_class " taskbarClass) {
                try taskListHwnd := this._FindTaskListHwnd(trayHwnd)
                catch
                    continue

                if !taskListHwnd
                    continue

                try uia := this._CreateUIAutomation()
                catch
                    continue

                try {
                    elementPtr := 0
                    if ComCall(9, uia, "ptr", taskListHwnd, "ptr*", &elementPtr) != 0 || !elementPtr
                        continue

                    element := ComValue(13, elementPtr)
                    if ComCall(21, uia, "ptr*", &conditionPtr := 0) != 0 || !conditionPtr
                        continue
                    condition := ComValue(13, conditionPtr)

                    elementsPtr := 0
                    if ComCall(6, element, "uint", 2, "ptr", condition, "ptr*", &elementsPtr) != 0 || !elementsPtr
                        continue
                    elements := ComValue(13, elementsPtr)

                    count := 0
                    if ComCall(3, elements, "int*", &count) != 0
                        continue

                    Loop count {
                        index := A_Index - 1
                        buttonPtr := 0
                        if ComCall(4, elements, "int", index, "ptr*", &buttonPtr) != 0 || !buttonPtr
                            continue

                        button := ComValue(13, buttonPtr)
                        if ComCall(21, button, "int*", &controlType := 0) != 0 || controlType != 50000
                            continue

                        automationId := ""
                        name := ""
                        if ComCall(29, button, "ptr*", &automationIdPtr := 0) = 0 && automationIdPtr
                            automationId := StrGet(automationIdPtr, "UTF-16")
                        if ComCall(23, button, "ptr*", &namePtr := 0) = 0 && namePtr
                            name := StrGet(namePtr, "UTF-16")

                        rect := Buffer(16, 0)
                        if ComCall(43, button, "ptr", rect) != 0
                            continue

                        left := NumGet(rect, 0, "Int")
                        top := NumGet(rect, 4, "Int")
                        right := NumGet(rect, 8, "Int")
                        bottom := NumGet(rect, 12, "Int")
                        width := right - left
                        height := bottom - top
                        if width <= 4 || height <= 4
                            continue

                        buttons.Push({
                            automationId: automationId,
                            name: name,
                            x: left,
                            y: top,
                            w: width,
                            h: height
                        })
                    }
                } catch {
                    continue
                }
            }
        }

        return buttons
    }

    static _FindTaskListHwnd(trayHwnd) {
        found := 0
        this._EnumTaskbarChildWindows(trayHwnd, &found)
        return found
    }

    static _EnumTaskbarChildWindows(parentHwnd, &found) {
        callback := CallbackCreate((hwnd, lParam) => {
            className := WinGetClass(hwnd)
            if className == "MSTaskListWClass" {
                NumPut("ptr", hwnd, lParam)
                return false
            }
            return true
        }, "Fast")

        buffer := Buffer(A_PtrSize, 0)
        DllCall("user32\EnumChildWindows", "ptr", parentHwnd, "ptr", callback, "ptr", buffer)
        CallbackFree(callback)
        found := NumGet(buffer, "ptr")
    }

    static _FindButtonForApp(buttons, appId) {
        if !appId
            return 0

        needle := StrLower(appId)
        for index, button in buttons {
            if StrLower(button.automationId) == needle
                return index
        }

        ; Some older taskbar providers expose a normalized executable-based
        ; automation id. Match that only as a fallback.
        exeName := StrLower(RegExReplace(appId, ".*[\\/]", ""))
        if exeName {
            for index, button in buttons {
                if InStr(StrLower(button.automationId), exeName)
                    return index
            }
        }

        return 0
    }

    static _ActivateTaskbarButton(button) {
        if !button
            return false

        oldMode := A_CoordModeMouse
        CoordMode("Mouse", "Screen")
        MouseGetPos(&oldX, &oldY)

        try {
            MouseMove(button.x + (button.w // 2), button.y + (button.h // 2), 0)
            Click("Left")
            Sleep(45)
            return true
        } finally {
            MouseMove(oldX, oldY, 0)
            CoordMode("Mouse", oldMode)
        }
    }

    static _CtrlClickButton(button) {
        if !button
            return 0

        oldMode := A_CoordModeMouse
        CoordMode("Mouse", "Screen")
        MouseGetPos(&oldX, &oldY)

        try {
            MouseMove(button.x + (button.w // 2), button.y + (button.h // 2), 0)
            SendEvent("{Ctrl down}")
            Click("Left")
            Sleep(45)
            return WinExist("A")
        } catch {
            return 0
        } finally {
            try SendEvent("{Ctrl up}")
            MouseMove(oldX, oldY, 0)
            CoordMode("Mouse", oldMode)
        }
    }

    static _SetNavigationState(button, index) {
        this._currentTaskbarIndex := index
        this._currentAppId := button.automationId
        this._groupWindows := []
        hwnd := WinExist("A")
        this._groupStartHwnd := hwnd
        if hwnd {
            this._groupWindows := [hwnd]
            this._groupIndex := 1
            this._lastActiveHwnd := hwnd
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

    static _ContainsHwnd(list, hwnd) {
        for existingHwnd in list {
            if existingHwnd == hwnd
                return true
        }
        return false
    }

    static _AdjacentIndex(count, index, forward) {
        if count <= 0
            return 0

        if forward {
            index += 1
            if index > count
                index := 1
        } else {
            index -= 1
            if index < 1
                index := count
        }

        return index
    }

    static _ResetIfExternalSwitch(currentHwnd) {
        if this._lastActiveHwnd && currentHwnd != this._lastActiveHwnd
            this._ResetState()
    }

    static _ResetState() {
        this._taskbarButtons := []
        this._currentAppId := ""
        this._currentTaskbarIndex := 0
        this._groupWindows := []
        this._groupIndex := 0
        this._groupStartHwnd := 0
        this._lastActiveHwnd := 0
    }

    static _CreateUIAutomation() {
        return ComObject(
            "{FF48DBA4-60EF-4201-AA87-54103EEF594E}",
            "{30CBE57D-D9D0-452A-AB13-7AC5AC4825EE}"
        )
    }

    static _GetAppUserModelId(hwnd) {
        if !hwnd
            return ""

        iid := Buffer(16, 0)
        if DllCall("ole32\CLSIDFromString", "wstr", "{886D8EEB-8CF2-4446-8D02-CDBA1DBDCF99}", "ptr", iid) != 0
            return ""

        storePtr := 0
        if DllCall("shell32\SHGetPropertyStoreForWindow", "ptr", hwnd, "ptr", iid, "ptr*", &storePtr) != 0 || !storePtr
            return ""

        store := ComValue(13, storePtr)
        pkey := Buffer(20, 0)
        if DllCall("ole32\CLSIDFromString", "wstr", "{9F4C2855-9F79-4B39-A8D0-E1D42DE1D5F3}", "ptr", pkey) != 0
            return ""
        NumPut("UInt", 5, pkey, 16)

        propvar := Buffer(24, 0)
        try {
            if ComCall(5, store, "ptr", pkey, "ptr", propvar) != 0
                return ""

            output := Buffer(1024, 0)
            if DllCall("propsys\PropVariantToString", "ptr", propvar, "ptr", output, "uint", 512) != 0
                return ""

            return StrGet(output, "UTF-16")
        } finally {
            DllCall("ole32\PropVariantClear", "ptr", propvar)
        }
    }

    static _GetProcessFallbackId(hwnd) {
        try
            return WinGetProcessName("ahk_id " hwnd)
        catch
            return ""
    }

    static _FallbackNext() {
        this._NativeTaskbarCycle(true)
    }

    static _FallbackPrev() {
        this._NativeTaskbarCycle(false)
    }

    static _NativeTaskbarCycle(forward) {
        this._ReleasePhysicalModifiers()
        try {
            if forward
                SendEvent("{LWin down}{t}{LWin up}")
            else
                SendEvent("{LWin down}{LShift down}{t}{LShift up}{LWin up}")
        } finally {
            this._RestorePhysicalShift()
        }
    }

    static _ReleasePhysicalModifiers() {
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
