#Requires AutoHotkey v2.0

; ---------------------------------------------------------------------------
; Window Hole service
;
; CapsLock + X temporarily removes a region around the mouse from the
; foreground window. Because the removed area is outside the window region,
; mouse hit-testing can reach the next window underneath.
;
; Region operations are native Win32 calls. Some modern/special windows reject
; SetWindowRgn or render their non-client frame incorrectly. Such windows are
; handled by a temporary minimize fallback and restored when the mode ends.
; ---------------------------------------------------------------------------
class WindowHole {
    static DWM_NCRENDERING_POLICY := 2
    static DWM_WINDOW_CORNER_PREFERENCE := 33
    static DWM_SYSTEMBACKDROP_TYPE := 38
    static DWMNCRP_DISABLED := 1
    static DWMWCP_DONOTROUND := 1
    static DWMSBT_NONE := 1
    static DPI_AWARENESS_CONTEXT_PER_MONITOR_AWARE_V2 := -4

    ; Chromium uses a high-frequency compositor path. Avoid issuing native
    ; region changes for sub-pixel-looking mouse motion and cap the update
    ; frequency without changing the normal-window configuration default.
    static CHROMIUM_MIN_UPDATE_INTERVAL := 80
    static CHROMIUM_MIN_MOVE_DISTANCE := 12
    ; Geometry is stable for normal cursor tracking; revalidate it periodically
    ; so window moves/resizes are detected without a GetWindowRect call on every
    ; Chromium region commit.
    static CHROMIUM_GEOMETRY_REFRESH_INTERVAL := 160
    static TASK_MANAGER_COMPANION_SCAN_INTERVAL := 200
    static TASK_MANAGER_COMPANION_MIN_REGION_COMMIT_INTERVAL := 80
    static TASK_MANAGER_COMPANION_MIN_MOVE_DISTANCE := 12

    static Active := false
    static SecondLevelActive := false
    static PrimaryHwnd := 0
    static SecondaryHwnd := 0
    static OriginalForeground := 0
    static OriginalTopmost := false
    static Targets := Map()
    static LastMouseX := ""
    static LastMouseY := ""
    static LastTaskManagerCompanionScanTick := 0
    static TimerCallback := ""
    static SecondLevelHotkeyCallback := ""
    static SecondLevelHotkeyEnabled := false
    static SecondLevelHotkeyKeyDown := false

    static IsActive() {
        return this.Active
    }

    static InitializeSecondLevelHotkey() {
        if IsObject(this.SecondLevelHotkeyCallback)
            return true

        this.SecondLevelHotkeyCallback := ObjBindMethod(this, "HandleSecondLevelHotkey")

        try {
            ; Always register the second-level key as a context-insensitive
            ; hotkey. Context-sensitive #HotIf evaluation can be delayed while
            ; the script is busy, which makes the X + 1 sequence intermittent.
            HotIf
            Hotkey("1", this.SecondLevelHotkeyCallback, "Off")
            this.SecondLevelHotkeyEnabled := false
            return true
        } catch {
            this.SecondLevelHotkeyCallback := ""
            this.SecondLevelHotkeyEnabled := false
            return false
        }
    }

    static _SetSecondLevelHotkeyEnabled(enabled) {
        if !IsObject(this.SecondLevelHotkeyCallback)
            return false

        try {
            HotIf
            Hotkey("1", enabled ? "On" : "Off")
            this.SecondLevelHotkeyEnabled := enabled
            return true
        } catch {
            this.SecondLevelHotkeyEnabled := false
            return false
        }
    }

    static HandleXDown(*) {
        mode := StrLower(AppState.WindowHoleActivation)
        if mode == "toggle"
            this.Toggle()
        else
            this.Start()
    }

    static HandleXUp(*) {
        if StrLower(AppState.WindowHoleActivation) == "hold"
            this.Stop()
    }

    static Toggle(*) {
        if this.Active
            this.Stop()
        else
            this.Start()
    }

    static Start(*) {
        if this.Active
            return

        hwnd := WinExist("A")
        if !hwnd || !this.IsEligible(hwnd)
            return

        this.Active := true
        this.SecondLevelActive := false
        this.PrimaryHwnd := hwnd
        this.SecondaryHwnd := 0
        this.OriginalForeground := hwnd
        this.OriginalTopmost := this.IsTopmost(hwnd)
        this.Targets := Map()
        this.LastMouseX := ""
        this.LastMouseY := ""

        ; Keep the original foreground window above the revealed content.
        ; The previous topmost state is restored when the mode ends.
        if !this.OriginalTopmost {
            try WinSetAlwaysOnTop(1, "ahk_id " hwnd)
        }

        if !this._ApplyHole(hwnd, true) {
            this._RestoreAll()
            this._RestorePrimaryTopmost()
            this._ResetState()
            return
        }

        ; Enable the second-level key only after the primary hole is fully
        ; established. This prevents a very fast X + 1 sequence from
        ; interrupting Start() while its target state is still incomplete.
        if !this._SetSecondLevelHotkeyEnabled(true) {
            this._RestoreAll()
            this._RestorePrimaryTopmost()
            this._ResetState()
            return
        }

        this.TimerCallback := (*) => this._Update()
        interval := Clamp(Integer(AppState.WindowHoleUpdateInterval), 15, 200)
        if this._IsChromiumWindow(hwnd)
            interval := Max(interval, this.CHROMIUM_MIN_UPDATE_INTERVAL)
        SetTimer(this.TimerCallback, interval)
        this._Update()
    }

    static Stop(*) {
        if !this.Active
            return

        try {
            if IsObject(this.TimerCallback)
                SetTimer(this.TimerCallback, 0)
        }

        this._SetSecondLevelHotkeyEnabled(false)
        this._RestoreAll()
        this._RestorePrimaryTopmost()

        original := this.OriginalForeground
        this._ResetState()

        if original && WinExist("ahk_id " original) {
            try WinActivate("ahk_id " original)
        }
    }

    static HandleSecondLevelHotkey(*) {
        if this.SecondLevelHotkeyKeyDown
            return

        this.SecondLevelHotkeyKeyDown := true
        try {
            this.ToggleSecondLevel()
        } finally {
            try {
                KeyWait("1")
            } finally {
                this.SecondLevelHotkeyKeyDown := false
            }
        }
    }

    static ToggleSecondLevel(*) {
        if !this.Active
            return

        if !AppState.WindowHoleSecondLevelEnabled {
            ShowToolTip(
                Lang(
                    "MSG_WINDOW_HOLE_SECOND_DISABLED",
                    "Second penetration disabled."
                ),
                1200
            )
            return
        }

        if !this.SecondLevelHotkeyEnabled {
            ShowToolTip(
                Lang(
                    "MSG_WINDOW_HOLE_SECOND_UNAVAILABLE",
                    "No eligible window is available for second penetration."
                ),
                1500
            )
            return
        }

        if this.SecondLevelActive {
            this.SecondLevelActive := false
            this.SecondaryHwnd := 0
            this._RemoveSecondaryTargets()

            ShowToolTip(
                Lang(
                    "MSG_WINDOW_HOLE_SECOND_DISABLED",
                    "Second penetration disabled."
                ),
                1200
            )
            return
        }

        try {
            MouseGetPos(&mouseX, &mouseY, &mouseHwnd)
            if !this._GetPhysicalCursorPosition(&mx, &my) {
                ShowToolTip(
                    Lang(
                        "MSG_WINDOW_HOLE_SECOND_UNAVAILABLE",
                        "No eligible window is available for second penetration."
                    ),
                    1500
                )
                return
            }

            secondaryHwnd := this._GetRootWindowAtPoint(mouseHwnd)
        } catch {
            ShowToolTip(
                Lang(
                    "MSG_WINDOW_HOLE_SECOND_UNAVAILABLE",
                    "No eligible window is available for second penetration."
                ),
                1500
            )
            return
        }

        if (
            !secondaryHwnd
            || secondaryHwnd == this.PrimaryHwnd
            || !this.IsEligible(secondaryHwnd)
        ) {
            ShowToolTip(
                Lang(
                    "MSG_WINDOW_HOLE_SECOND_UNAVAILABLE",
                    "No eligible window is available for second penetration."
                ),
                1500
            )
            return
        }

        result := this._ApplyHole(
            secondaryHwnd,
            false,
            mx,
            my
        )

        if !result {
            this.SecondaryHwnd := 0
            ShowToolTip(
                Lang(
                    "MSG_WINDOW_HOLE_SECOND_UNAVAILABLE",
                    "No eligible window is available for second penetration."
                ),
                1500
            )
            return
        }

        this.SecondaryHwnd := secondaryHwnd
        this.SecondLevelActive := true

        targetName := this._GetWindowLabel(secondaryHwnd)

        message := Lang(
            "MSG_WINDOW_HOLE_SECOND_ENABLED",
            "Second penetration enabled."
        )

        if targetName != ""
            message .= " — " targetName

        ShowToolTip(message, 1500)
    }

    static IsEligible(hwnd) {
        if !hwnd || !WinExist("ahk_id " hwnd)
            return false

        try {
            if WinGetMinMax("ahk_id " hwnd) == -1
                return false

            className := WinGetClass("ahk_id " hwnd)
            processName := ""
            try processName := WinGetProcessName("ahk_id " hwnd)
            catch {
                ; Protected/special windows can reject process-name queries.
                ; They are still eligible unless an executable allow-list is
                ; explicitly configured.
            }

            ; Do not manipulate the shell/taskbar surface as a lower
            ; penetration target.
            if className == "Shell_TrayWnd"
                return false
            if className == "Shell_SecondaryTrayWnd"
                return false

            for blockedClass in ["Progman", "WorkerW"] {
                if className == blockedClass
                    return false
            }

            if AppState.WindowHoleAllowedExecutables.Length > 0
                && !this._ListContains(AppState.WindowHoleAllowedExecutables, processName)
                return false

            if AppState.WindowHoleExcludedExecutables.Length > 0
                && this._ListContains(AppState.WindowHoleExcludedExecutables, processName)
                return false

            if AppState.WindowHoleAllowedClasses.Length > 0
                && !this._ListContains(AppState.WindowHoleAllowedClasses, className)
                return false

            if AppState.WindowHoleExcludedClasses.Length > 0
                && this._ListContains(AppState.WindowHoleExcludedClasses, className)
                return false

            return true
        } catch {
            return false
        }
    }

    static _Update(force := false) {
        if !this.Active
            return

        if !this._GetPhysicalCursorPosition(&mx, &my)
            return

        mouseMoved := force || mx != this.LastMouseX || my != this.LastMouseY

        this.LastMouseX := mx
        this.LastMouseY := my

        if this._IsTaskManagerWindow(this.PrimaryHwnd)
            this._EnsureTaskManagerCompanions()

        primaryState := this.Targets.Has(this.PrimaryHwnd) ? this.Targets[this.PrimaryHwnd] : ""
        if IsObject(primaryState) && !primaryState.fallback {
            ; The hole follows the cursor only while the cursor is still
            ; geometrically inside the primary window. Once the cursor passes
            ; through the hole into a lower window, freeze the hole in place.
            ; This is essential for real drag/drop: the cursor must be able
            ; to leave the hole and hit the primary window again.
            if mouseMoved && this._IsPointInsideWindow(
                this.PrimaryHwnd,
                mx,
                my,
                primaryState
            ) {
                if this._ShouldApplyPosition(primaryState, mx, my) {
                    if !this._ApplyHole(this.PrimaryHwnd, true, mx, my) {
                        this.Stop()
                        return
                    }
                }
            }
        }

        if this._IsTaskManagerWindow(this.PrimaryHwnd)
            this._UpdateTaskManagerCompanions(mx, my, mouseMoved)

        if !this.SecondLevelActive || !this.SecondaryHwnd
            return

        ; Layer 2 is locked to the window selected when CapsLock + 1
        ; was pressed. Do not discover deeper windows while moving.
        if !WinExist("ahk_id " this.SecondaryHwnd) {
            this.SecondLevelActive := false
            this.SecondaryHwnd := 0
            this._RemoveSecondaryTargets()

            ShowToolTip(
                Lang(
                    "MSG_WINDOW_HOLE_SECOND_DISABLED",
                    "Second penetration disabled."
                ),
                1500
            )
            return
        }

        ; Apply the second-layer hole only while the cursor is inside that
        ; target. Once the cursor penetrates beyond it, freeze the layer too.
        secondaryState := this.Targets.Has(this.SecondaryHwnd)
            ? this.Targets[this.SecondaryHwnd]
            : ""

        if !IsObject(secondaryState) || secondaryState.fallback
            return

        if !this._IsPointInsideWindow(
            this.SecondaryHwnd,
            mx,
            my,
            secondaryState
        )
            return

        if mouseMoved && this._ShouldApplyPosition(secondaryState, mx, my) {
            result := this._ApplyHole(
                this.SecondaryHwnd,
                false,
                mx,
                my
            )

            if !result {
                this.SecondLevelActive := false
                this.SecondaryHwnd := 0
                this._RemoveSecondaryTargets()

                ShowToolTip(
                    Lang(
                        "MSG_WINDOW_HOLE_SECOND_DISABLED",
                        "Second penetration disabled."
                    ),
                    1500
                )
            }
        }
    }

    static _GetPhysicalCursorPosition(&x, &y) {
        x := 0
        y := 0

        previousContext := 0
        contextChanged := false

        try {
            previousContext := DllCall(
                "SetThreadDpiAwarenessContext",
                "Ptr", this.DPI_AWARENESS_CONTEXT_PER_MONITOR_AWARE_V2,
                "Ptr"
            )
            contextChanged := previousContext != 0

            point := Buffer(8, 0)
            if !DllCall("GetCursorPos", "Ptr", point, "Int")
                return false

            x := NumGet(point, 0, "Int")
            y := NumGet(point, 4, "Int")
            return true
        } catch {
            return false
        } finally {
            if contextChanged {
                try DllCall(
                    "SetThreadDpiAwarenessContext",
                    "Ptr", previousContext,
                    "Ptr"
                )
            }
        }
    }

    static _GetPhysicalWindowGeometry(hwnd, &x, &y, &width, &height) {
        x := 0
        y := 0
        width := 0
        height := 0

        if !hwnd
            return false

        previousContext := 0
        contextChanged := false

        try {
            previousContext := DllCall(
                "SetThreadDpiAwarenessContext",
                "Ptr", this.DPI_AWARENESS_CONTEXT_PER_MONITOR_AWARE_V2,
                "Ptr"
            )
            contextChanged := previousContext != 0

            rect := Buffer(16, 0)
            if !DllCall("GetWindowRect", "Ptr", hwnd, "Ptr", rect, "Int")
                return false

            left := NumGet(rect, 0, "Int")
            top := NumGet(rect, 4, "Int")
            right := NumGet(rect, 8, "Int")
            bottom := NumGet(rect, 12, "Int")

            x := left
            y := top
            width := right - left
            height := bottom - top
            return width > 0 && height > 0
        } catch {
            return false
        } finally {
            if contextChanged {
                try DllCall(
                    "SetThreadDpiAwarenessContext",
                    "Ptr", previousContext,
                    "Ptr"
                )
            }
        }
    }

    static _IsChromiumWindow(hwnd) {
        if !hwnd || !WinExist("ahk_id " hwnd)
            return false

        try {
            processName := StrLower(WinGetProcessName("ahk_id " hwnd))
            return processName == "chrome.exe"
                || processName == "msedge.exe"
                || processName == "brave.exe"
                || processName == "thorium.exe"
                || processName == "vivaldi.exe"
                || processName == "opera.exe"
                || processName == "chromium.exe"
        } catch {
            return false
        }
    }

    static _IsTaskManagerWindow(hwnd) {
        if !hwnd || !WinExist("ahk_id " hwnd)
            return false

        try {
            return StrLower(WinGetProcessName("ahk_id " hwnd)) == "taskmgr.exe"
                && WinGetClass("ahk_id " hwnd) == "TaskManagerWindow"
        } catch {
            return false
        }
    }

    static _IsTaskManagerCompanionWindow(hwnd) {
        if !hwnd || !WinExist("ahk_id " hwnd)
            return false

        try {
            if StrLower(WinGetProcessName("ahk_id " hwnd)) != "taskmgr.exe"
                return false

            if !(WinGetStyle("ahk_id " hwnd) & 0x10000000)
                return false

            className := WinGetClass("ahk_id " hwnd)

            return className == "GlassWindow"
                || className == "FilterControlGlassWindow"
                || className == "NativeHWNDHost"
        } catch {
            return false
        }
    }

    static _IsTaskManagerSurface(hwnd) {
        return this._IsTaskManagerWindow(hwnd)
            || this._IsTaskManagerCompanionWindow(hwnd)
    }

    static _EnsureTaskManagerCompanions() {
        if !this._IsTaskManagerWindow(this.PrimaryHwnd)
            return

        now := A_TickCount

        if now - this.LastTaskManagerCompanionScanTick
            < this.TASK_MANAGER_COMPANION_SCAN_INTERVAL
            return

        this.LastTaskManagerCompanionScanTick := now
        seen := Map()

        try {
            hwnds := WinGetList("ahk_exe Taskmgr.exe")
        } catch {
            return
        }

        for hwnd in hwnds {
            if hwnd == this.PrimaryHwnd
                continue

            if !this._IsTaskManagerCompanionWindow(hwnd)
                continue

            if !this.IsEligible(hwnd)
                continue

            seen[hwnd] := true

            if !this.Targets.Has(hwnd) {
                state := this._CaptureState(hwnd)

                if !IsObject(state)
                    continue

                state.taskManagerSurface := true
                state.taskManagerCompanion := true
                this.Targets[hwnd] := state
            }
        }

        stale := []

        for hwnd, state in this.Targets {
            if !IsObject(state) || !state.taskManagerCompanion
                continue

            if seen.Has(hwnd)
                continue

            this._RestoreTarget(hwnd, state)
            stale.Push(hwnd)
        }

        for hwnd in stale {
            if this.Targets.Has(hwnd)
                this.Targets.Delete(hwnd)
        }
    }

    static _ShouldApplyTaskManagerCompanionPosition(state, x, y) {
        if !IsObject(state) || !state.taskManagerCompanion || !state.hasAppliedPosition
            return true

        if A_TickCount - state.taskManagerCompanionLastRegionCommitTick
            < this.TASK_MANAGER_COMPANION_MIN_REGION_COMMIT_INTERVAL
            return false

        return Max(
            Abs(x - state.lastAppliedX),
            Abs(y - state.lastAppliedY)
        ) >= this.TASK_MANAGER_COMPANION_MIN_MOVE_DISTANCE
    }

    static _UpdateTaskManagerCompanions(x, y, mouseMoved) {
        if !mouseMoved
            return

        companionHwnds := []

        for hwnd, state in this.Targets {
            if IsObject(state) && state.taskManagerCompanion
                companionHwnds.Push(hwnd)
        }

        for hwnd in companionHwnds {
            if !this.Targets.Has(hwnd)
                continue

            state := this.Targets[hwnd]

            if !IsObject(state) || state.fallback
                continue

            if !this._IsPointInsideWindow(hwnd, x, y, state)
                continue

            if !this._ShouldApplyTaskManagerCompanionPosition(state, x, y)
                continue

            result := this._ApplyHole(hwnd, false, x, y)

            if !result && this.Targets.Has(hwnd)
                this.Targets.Delete(hwnd)
        }
    }

    static _ShouldApplyPosition(state, x, y) {
        if !IsObject(state) || !state.isChromium || !state.hasAppliedPosition
            return true

        return Max(
            Abs(x - state.lastAppliedX),
            Abs(y - state.lastAppliedY)
        ) >= this.CHROMIUM_MIN_MOVE_DISTANCE
    }

    static _EnsureWindowGeometry(hwnd, state, force := false) {
        if !hwnd || !IsObject(state)
            return false

        now := A_TickCount
        if (
            state.isChromium
            && state.hasGeometry
            && !force
            && now - state.geometryLastRefreshTick < this.CHROMIUM_GEOMETRY_REFRESH_INTERVAL
        )
            return true

        if !WinExist("ahk_id " hwnd)
            return false

        if !this._GetPhysicalWindowGeometry(hwnd, &wx, &wy, &ww, &wh)
            return false

        if ww <= 0 || wh <= 0
            return false

        state.windowX := wx
        state.windowY := wy
        state.windowWidth := ww
        state.windowHeight := wh
        state.hasGeometry := true
        state.geometryLastRefreshTick := now
        return true
    }

    static _IsPointInsideWindow(hwnd, x, y, state := "") {
        if !hwnd
            return false

        if IsObject(state) && state.isChromium {
            if !this._EnsureWindowGeometry(hwnd, state)
                return false

            if state.hasGeometry
                return x >= state.windowX
                    && x < state.windowX + state.windowWidth
                    && y >= state.windowY
                    && y < state.windowY + state.windowHeight

            return false
        }

        if !WinExist("ahk_id " hwnd)
            return false

        try {
            if !this._GetPhysicalWindowGeometry(hwnd, &wx, &wy, &ww, &wh)
                return false

            return x >= wx && x < wx + ww && y >= wy && y < wy + wh
        } catch {
            return false
        }
    }
    static _GetRootWindowAtPoint(hwnd) {
        if !hwnd
            return 0

        try {
            root := DllCall(
                "GetAncestor",
                "Ptr", hwnd,
                "UInt", 2,
                "Ptr"
            )
            return root ? root : hwnd
        } catch {
            return hwnd
        }
    }

    static _ApplyHole(hwnd, isPrimary, mouseX := "", mouseY := "") {
        if !this.Targets.Has(hwnd) {
            if !this.IsEligible(hwnd)
                return false

            state := this._CaptureState(hwnd)
            if !IsObject(state)
                return false

            this.Targets[hwnd] := state
            this._PrepareWindowForHole(hwnd, state)
        }

        state := this.Targets[hwnd]

        if state.fallback
            return "minimized"

        try {
            if !this._EnsureWindowGeometry(hwnd, state)
                throw Error("Could not get physical window geometry.")

            wx := state.windowX
            wy := state.windowY
            ww := state.windowWidth
            wh := state.windowHeight

            if (ww <= 0 || wh <= 0)
                throw Error("Invalid window dimensions.")

            if mouseX == "" {
                if !this._GetPhysicalCursorPosition(&mx, &my)
                    throw Error("Could not get physical cursor position.")
            } else {
                mx := mouseX
                my := mouseY
            }

            firstRegionApply := !state.hasAppliedPosition

            relativeX := mx - wx
            relativeY := my - wy
            baseRegion := state.hadOriginalRegion
                ? state.originalRegion
                : this._EnsureBaseRegion(state, ww, wh)

            if !baseRegion
                throw Error("Could not prepare base window region.")

            region := this._CreateDifferenceRegion(
                ww,
                wh,
                relativeX,
                relativeY,
                baseRegion
            )

            if !region
                throw Error("Could not create window-hole region.")

            if DllCall(
                "PtInRegion",
                "Ptr", region,
                "Int", Floor(relativeX),
                "Int", Floor(relativeY),
                "Int"
            ) != 0 {
                throw Error("Window-hole center remained inside the assigned region.")
            }

            applied := DllCall(
                "SetWindowRgn",
                "Ptr", hwnd,
                "Ptr", region,
                "Int", state.isChromium ? 0 : 1,
                "Int"
            )

            if !applied {
                DllCall("DeleteObject", "Ptr", region)
                throw Error("SetWindowRgn failed.")
            }

            ; After SetWindowRgn succeeds, Windows owns the region handle.
            state.regionActive := true

            state.lastAppliedX := mx
            state.lastAppliedY := my
            state.hasAppliedPosition := true

            if state.taskManagerCompanion
                state.taskManagerCompanionLastRegionCommitTick := A_TickCount

            ; SetWindowRgn(..., FALSE) is intentionally the only operation in
            ; the steady-state Chromium movement path. Chromium treats region
            ; changes as paint-affecting operations already, so an additional
            ; RedrawWindow here only adds more work to its compositor path.
            ; Keep the explicit refresh for the first region application so
            ; activation remains visually immediate.
            if !state.isChromium || firstRegionApply
                this._RefreshWindow(hwnd, false, state.isChromium)

            return true
        } catch {
            if AppState.WindowHoleFallbackToMinimize
                && !state.taskManagerCompanion {
                if state.regionActive
                    this._RestoreOriginalRegion(hwnd, state)

                if this._MinimizeFallback(hwnd, state)
                    return "minimized"
            }

            this._RestoreWindowVisualState(hwnd, state)
            this._DiscardCapturedRegion(state)

            if state.baseRegion {
                try DllCall("DeleteObject", "Ptr", state.baseRegion)
                state.baseRegion := 0
                state.baseRegionWidth := 0
                state.baseRegionHeight := 0
            }

            this.Targets.Delete(hwnd)
            return false
        }
    }

    static _EnsureBaseRegion(state, width, height) {
        if !IsObject(state)
            return 0

        if (
            state.baseRegion
            && state.baseRegionWidth == width
            && state.baseRegionHeight == height
        )
            return state.baseRegion

        if state.baseRegion {
            try DllCall("DeleteObject", "Ptr", state.baseRegion)
            state.baseRegion := 0
            state.baseRegionWidth := 0
            state.baseRegionHeight := 0
        }

        region := DllCall(
            "CreateRectRgn",
            "Int", 0,
            "Int", 0,
            "Int", width,
            "Int", height,
            "Ptr"
        )

        if !region
            return 0

        state.baseRegion := region
        state.baseRegionWidth := width
        state.baseRegionHeight := height
        return region
    }

    static _CreateDifferenceRegion(
        width,
        height,
        centerX,
        centerY,
        baseRegion := 0
    ) {
        diameter := Clamp(Integer(AppState.WindowHoleDiameter), 80, 1200)
        radius := Floor(diameter / 2)

        source := baseRegion
        ownsSource := false

        if !source {
            source := DllCall(
                "CreateRectRgn",
                "Int", 0,
                "Int", 0,
                "Int", width,
                "Int", height,
                "Ptr"
            )

            if !source
                return 0

            ownsSource := true
        }

        shape := StrLower(AppState.WindowHoleShape)
        hole := 0

        try {
            if shape == "square" {
                hole := DllCall(
                    "CreateRectRgn",
                    "Int", centerX - radius,
                    "Int", centerY - radius,
                    "Int", centerX + radius,
                    "Int", centerY + radius,
                    "Ptr"
                )
            } else if shape == "rounded" {
                corner := Max(20, Floor(diameter / 4))
                hole := DllCall(
                    "CreateRoundRectRgn",
                    "Int", centerX - radius,
                    "Int", centerY - radius,
                    "Int", centerX + radius,
                    "Int", centerY + radius,
                    "Int", corner,
                    "Int", corner,
                    "Ptr"
                )
            } else {
                hole := DllCall(
                    "CreateEllipticRgn",
                    "Int", centerX - radius,
                    "Int", centerY - radius,
                    "Int", centerX + radius,
                    "Int", centerY + radius,
                    "Ptr"
                )
            }

            if !hole
                throw Error("Could not create hole region.")

            result := DllCall(
                "CreateRectRgn",
                "Int", 0,
                "Int", 0,
                "Int", 0,
                "Int", 0,
                "Ptr"
            )

            if !result
                throw Error("Could not create result region.")

            combined := DllCall(
                "CombineRgn",
                "Ptr", result,
                "Ptr", source,
                "Ptr", hole,
                "Int", 4,
                "Int"
            )

            if combined == 0 {
                DllCall("DeleteObject", "Ptr", result)
                throw Error("Could not combine window-hole regions.")
            }

            return result
        } catch {
            return 0
        } finally {
            if hole
                DllCall("DeleteObject", "Ptr", hole)
            if ownsSource && source
                DllCall("DeleteObject", "Ptr", source)
        }
    }

    static _CaptureState(hwnd) {
        state := {
            originalRegion: 0,
            hadOriginalRegion: false,
            regionActive: false,
            fallback: false,
            fallbackPreviousState: 0,
            isChromium: this._IsChromiumWindow(hwnd),
            taskManagerSurface: this._IsTaskManagerSurface(hwnd),
            taskManagerCompanion: this._IsTaskManagerCompanionWindow(hwnd),
            taskManagerCompanionLastRegionCommitTick: 0,
            lastAppliedX: 0,
            lastAppliedY: 0,
            hasAppliedPosition: false,
            windowX: 0,
            windowY: 0,
            windowWidth: 0,
            windowHeight: 0,
            baseRegion: 0,
            baseRegionWidth: 0,
            baseRegionHeight: 0,
            hwnd: hwnd,
            hasGeometry: false,
            geometryLastRefreshTick: 0,
            originalNCRenderingPolicy: 0,
            hadOriginalNCRenderingPolicy: false,
            visualPrepared: false,
            originalOpacity: 255,
            hadOriginalOpacity: false,
            originalCornerPreference: 0,
            hadOriginalCornerPreference: false,
            originalSystemBackdropType: 0,
            hadOriginalSystemBackdropType: false
        }

        tempRegion := DllCall(
            "CreateRectRgn",
            "Int", 0,
            "Int", 0,
            "Int", 1,
            "Int", 1,
            "Ptr"
        )

        if !tempRegion
            return 0

        try {
            type := DllCall(
                "GetWindowRgn",
                "Ptr", hwnd,
                "Ptr", tempRegion,
                "Int"
            )

            if type > 0 {
                state.hadOriginalRegion := true
                state.originalRegion := tempRegion
                tempRegion := 0
            }

            if this._DwmGetIntAttribute(
                hwnd,
                this.DWM_NCRENDERING_POLICY,
                &ncrp
            ) {
                state.hadOriginalNCRenderingPolicy := true
                state.originalNCRenderingPolicy := ncrp
            }

            return state
        } catch {
            return 0
        } finally {
            if tempRegion
                DllCall("DeleteObject", "Ptr", tempRegion)
        }
    }

    static _DwmGetIntAttribute(hwnd, attribute, &value) {
        value := 0
        attributeBuffer := Buffer(4, 0)

        try {
            hr := DllCall(
                "dwmapi\DwmGetWindowAttribute",
                "Ptr", hwnd,
                "UInt", attribute,
                "Ptr", attributeBuffer,
                "UInt", 4,
                "Int"
            )

            if hr != 0
                return false

            value := NumGet(attributeBuffer, 0, "Int")
            return true
        } catch {
            return false
        }
    }

    static _DwmSetIntAttribute(hwnd, attribute, value) {
        attributeBuffer := Buffer(4, 0)
        NumPut("Int", value, attributeBuffer)

        try {
            hr := DllCall(
                "dwmapi\DwmSetWindowAttribute",
                "Ptr", hwnd,
                "UInt", attribute,
                "Ptr", attributeBuffer,
                "UInt", 4,
                "Int"
            )
            return hr == 0
        } catch {
            return false
        }
    }

    static _PrepareWindowForHole(hwnd, state) {
        if !IsObject(state) || !WinExist("ahk_id " hwnd)
            return

        ; Task Manager and its modern helper surfaces can retain DWM-
        ; rendered backdrop/frame pixels when a custom window region is used.
        ; Keep the same visual sanitization path as other Win11 windows and
        ; restore every captured attribute when the Window Hole session ends.
        ; This is intentionally done for Task Manager surfaces as a compatibility
        ; requirement; bypassing this path leaves the carved area visually opaque.

        ; A window may already be partially transparent because of the
        ; CapsLock opacity controls. Window Hole needs an opaque source
        ; surface so the excluded region is the only visual gap.
        try {
            opacity := WinGetTransparent("ahk_id " hwnd)
            if IsNumber(opacity) {
                state.hadOriginalOpacity := true
                state.originalOpacity := Integer(opacity)

                if state.originalOpacity < 255
                    WinSetTransparent(255, "ahk_id " hwnd)
            }
        } catch {
        }

        ; A custom external region must not coexist with DWM-rendered
        ; non-client/backdrop pixels. Apply these policies once at session
        ; start, but never force SWP_FRAMECHANGED on Chromium while the hole
        ; is moving.
        if state.hadOriginalNCRenderingPolicy {
            this._DwmSetIntAttribute(
                hwnd,
                this.DWM_NCRENDERING_POLICY,
                this.DWMNCRP_DISABLED
            )
        }

        if this._DwmGetIntAttribute(hwnd, this.DWM_SYSTEMBACKDROP_TYPE, &backdropType) {
            state.hadOriginalSystemBackdropType := true
            state.originalSystemBackdropType := backdropType
            this._DwmSetIntAttribute(
                hwnd,
                this.DWM_SYSTEMBACKDROP_TYPE,
                this.DWMSBT_NONE
            )
        }

        if this._DwmGetIntAttribute(hwnd, this.DWM_WINDOW_CORNER_PREFERENCE, &cornerPreference) {
            state.hadOriginalCornerPreference := true
            state.originalCornerPreference := cornerPreference
            this._DwmSetIntAttribute(
                hwnd,
                this.DWM_WINDOW_CORNER_PREFERENCE,
                this.DWMWCP_DONOTROUND
            )
        }

        state.visualPrepared := true
        frameChanged := !state.isChromium
        this._RefreshWindow(hwnd, frameChanged, state.isChromium)
    }

    static _RestoreWindowVisualState(hwnd, state) {
        if !IsObject(state) || !state.visualPrepared
            return

        if WinExist("ahk_id " hwnd) {
            ; Restore the exact DWM state captured at session start.
            if state.hadOriginalNCRenderingPolicy
                this._DwmSetIntAttribute(
                    hwnd,
                    this.DWM_NCRENDERING_POLICY,
                    state.originalNCRenderingPolicy
                )

            if state.hadOriginalSystemBackdropType
                this._DwmSetIntAttribute(
                    hwnd,
                    this.DWM_SYSTEMBACKDROP_TYPE,
                    state.originalSystemBackdropType
                )

            if state.hadOriginalCornerPreference
                this._DwmSetIntAttribute(
                    hwnd,
                    this.DWM_WINDOW_CORNER_PREFERENCE,
                    state.originalCornerPreference
                )

            if state.hadOriginalOpacity
                try WinSetTransparent(state.originalOpacity, "ahk_id " hwnd)

            frameChanged := !state.isChromium
            this._RefreshWindow(hwnd, frameChanged, state.isChromium)
        }

        state.visualPrepared := false
    }

    static _RefreshWindow(hwnd, frameChanged := false, chromium := false) {
        if !hwnd || !WinExist("ahk_id " hwnd)
            return

        ; DWM-backed/custom-framed windows may cache their non-client metrics.
        ; SWP_FRAMECHANGED forces Windows to recalculate the frame after a
        ; temporary DWM non-client rendering policy change.
        if frameChanged {
            try DllCall(
                "SetWindowPos",
                "Ptr", hwnd,
                "Ptr", 0,
                "Int", 0,
                "Int", 0,
                "Int", 0,
                "Int", 0,
                "UInt",
                0x0001 ; SWP_NOSIZE
                | 0x0002 ; SWP_NOMOVE
                | 0x0004 ; SWP_NOZORDER
                | 0x0010 ; SWP_NOACTIVATE
                | 0x0020 ; SWP_FRAMECHANGED
            )
        }

        redrawFlags := chromium
            ? 0x0001 | 0x0020
            : 0x0001 | 0x0004 | 0x0080 | 0x0100 | 0x0200 | 0x0400

        try DllCall(
            "RedrawWindow",
            "Ptr", hwnd,
            "Ptr", 0,
            "Ptr", 0,
            "UInt", redrawFlags
        )

        if !chromium
            try DllCall("UpdateWindow", "Ptr", hwnd)


    }

    static _RestoreOriginalRegion(hwnd, state) {
        if !IsObject(state) || !WinExist("ahk_id " hwnd)
            return

        if state.regionActive {
            if state.hadOriginalRegion && state.originalRegion {
                restored := 0
                try {
                    restored := DllCall(
                        "SetWindowRgn",
                        "Ptr", hwnd,
                        "Ptr", state.originalRegion,
                        "Int", state.isChromium ? 0 : 1,
                        "Int"
                    )
                }

                if restored {
                    ; Windows owns the restored original-region handle.
                    state.originalRegion := 0
                } else if state.originalRegion {
                    DllCall("DeleteObject", "Ptr", state.originalRegion)
                    state.originalRegion := 0
                    try DllCall("SetWindowRgn", "Ptr", hwnd, "Ptr", 0, "Int", 1, "Int")
                }
            } else {
                try DllCall(
                    "SetWindowRgn",
                    "Ptr", hwnd,
                    "Ptr", 0,
                    "Int", state.isChromium ? 0 : 1,
                    "Int"
                )
            }

            this._RefreshWindow(hwnd, false, state.isChromium)
            state.regionActive := false
        }
    }


    static _DiscardCapturedRegion(state) {
        if IsObject(state) && state.originalRegion {
            try DllCall("DeleteObject", "Ptr", state.originalRegion)
            state.originalRegion := 0
        }
    }

    static _MinimizeFallback(hwnd, state) {
        if !AppState.WindowHoleFallbackToMinimize
            return false

        if !WinExist("ahk_id " hwnd)
            return false

        try {
            previousState := WinGetMinMax("ahk_id " hwnd)
            if previousState == -1
                return false

            WinMinimize("ahk_id " hwnd)
            Sleep(10)

            if WinGetMinMax("ahk_id " hwnd) != -1
                throw Error("WinMinimize failed.")

            state.fallback := true
            state.fallbackPreviousState := previousState
            ShowToolTip(
                Lang("MSG_WINDOW_HOLE_FALLBACK_USED", "Incompatible window temporarily minimized."),
                1500
            )
            return true
        } catch {
            return false
        }
    }

    static _RestoreFallback(hwnd, previousState) {
        if !hwnd || !WinExist("ahk_id " hwnd)
            return

        try {
            WinRestore("ahk_id " hwnd)

            if previousState == 1
                WinMaximize("ahk_id " hwnd)
        } catch {
        }
    }

    static _RestoreAll() {
        secondaryHwnds := []
        for hwnd, state in this.Targets {
            if hwnd == this.PrimaryHwnd
                continue
            secondaryHwnds.Push(hwnd)
        }

        ; Restore lower layers first, then the primary window.
        for hwnd in secondaryHwnds {
            if this.Targets.Has(hwnd)
                this._RestoreTarget(hwnd, this.Targets[hwnd])
        }

        if this.PrimaryHwnd && this.Targets.Has(this.PrimaryHwnd)
            this._RestoreTarget(this.PrimaryHwnd, this.Targets[this.PrimaryHwnd])

        this.Targets := Map()
    }

    static _RestoreTarget(hwnd, state) {
        if !IsObject(state)
            return

        ; Restore DWM/opacity state before returning the original region.
        this._RestoreWindowVisualState(hwnd, state)

        if state.regionActive
            this._RestoreOriginalRegion(hwnd, state)

        if state.fallback
            this._RestoreFallback(hwnd, state.fallbackPreviousState)

        if state.originalRegion
            this._DiscardCapturedRegion(state)

        if state.baseRegion {
            try DllCall("DeleteObject", "Ptr", state.baseRegion)
            state.baseRegion := 0
            state.baseRegionWidth := 0
            state.baseRegionHeight := 0
        }

        state.fallback := false
    }

    static _RemoveSecondaryTargets() {
        secondaryHwnds := []
        for hwnd, state in this.Targets {
            if hwnd != this.PrimaryHwnd
                secondaryHwnds.Push(hwnd)
        }

        for hwnd in secondaryHwnds {
            state := this.Targets[hwnd]
            this._RestoreTarget(hwnd, state)
            this.Targets.Delete(hwnd)
        }

        this.SecondaryHwnd := 0
    }

    static _RestorePrimaryTopmost() {
        hwnd := this.PrimaryHwnd
        if !hwnd || !WinExist("ahk_id " hwnd)
            return

        try WinSetAlwaysOnTop(this.OriginalTopmost ? 1 : 0, "ahk_id " hwnd)
    }

    static _ResetState() {
        this._SetSecondLevelHotkeyEnabled(false)
        this.Active := false
        this.SecondLevelActive := false
        this.PrimaryHwnd := 0
        this.SecondaryHwnd := 0
        this.OriginalForeground := 0
        this.OriginalTopmost := false
        this.Targets := Map()
        this.LastMouseX := ""
        this.LastMouseY := ""
        this.LastTaskManagerCompanionScanTick := 0
        this.TimerCallback := ""
    }

    static IsTopmost(hwnd) {
        try {
            return (WinGetExStyle("ahk_id " hwnd) & 0x8) != 0
        } catch {
            return false
        }
    }

    static _GetWindowLabel(hwnd) {
        if !hwnd || !WinExist("ahk_id " hwnd)
            return ""

        try {
            title := Trim(WinGetTitle("ahk_id " hwnd))
            if title != ""
                return title

            return Trim(WinGetProcessName("ahk_id " hwnd))
        } catch {
            return ""
        }
    }

    static _ListContains(arr, value) {
        needle := StrLower(Trim(value))
        if needle == ""
            return false

        for item in arr {
            if StrLower(Trim(item)) == needle
                return true
        }
        return false
    }
}
