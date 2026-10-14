#Requires AutoHotkey v2.0

; ---------------------------------------------------------------------------
; Always-on-top state indicator
;
; CapsLock + T toggles WS_EX_TOPMOST on the active window, but the only
; feedback was a transient OSD toast. Once it faded, there was no way to tell
; a pinned window from an unpinned one without pressing the shortcut again and
; remembering which state it was in.
;
; PinIndicator keeps a small click-through badge on the title bar of every
; topmost window it manages:
;
;     pinned    -> badge visible
;     unpinned  -> no badge
;
; The two states therefore stay distinguishable at a glance, and the badge is
; small enough (about 22 px at 96 DPI) that it never hides content.
;
; Guarantees
;   * The tracked set is re-validated against the *real* WS_EX_TOPMOST style
;     on every tick, so a window unpinned by any other program (or by
;     restarting an app) loses its badge instead of showing a stale one.
;   * Geometry is re-read every tick, so moving, resizing, maximizing,
;     minimizing, restoring or dragging to another monitor keeps the badge
;     aligned.
;   * Sizes are derived from the target window's DPI, so the glyph stays
;     legible at 100/125/150/200 % scaling and on mixed-DPI setups.
;   * The badge is WS_EX_TRANSPARENT (click-through) plus WS_EX_NOACTIVATE, so
;     it never captures input and never steals focus. Clicks land on the
;     title bar underneath, which is a non-destructive drag target.
;   * The badge is an independent topmost popup. Its visibility is controlled
;     explicitly so Windows cannot strand an owned badge hidden on restore.
; ---------------------------------------------------------------------------
class PinIndicator {
    ; --- Tunables ---
    static UpdateInterval := 16        ; near-frame updates keep the badge attached while dragging
    static BaseSize       := 22        ; badge edge length at 96 DPI
    static BaseOffset     := 4         ; gap from the window corner at 96 DPI
    static DefaultDpi           := 96
    static EVENT_SYSTEM_FOREGROUND    := 0x0003
    static EVENT_SYSTEM_MINIMIZESTART := 0x0016
    static EVENT_SYSTEM_MINIMIZEEND   := 0x0017
    static EVENT_OBJECT_SHOW          := 0x8002
    static EVENT_OBJECT_HIDE          := 0x8003
    static OBJID_WINDOW               := 0
    static CHILDID_SELF               := 0
    static EVENT_DEBOUNCE_MS          := 50
    static ZOrderRetryIntervalMs      := 50
    static ZOrderRetryAttempts        := 16
    static TRANSITION_NONE            := 0
    static TRANSITION_MINIMIZING       := 1
    static TRANSITION_RESTORING        := 2
    static TransitionTimeoutMs         := 2500

    ; --- Runtime state ---
    static Enabled              := true
    static Tracked              := Map()  ; hwnd -> badge geometry, visibility, and restore state
    static TimerCallback        := ""
    static WinEventHook         := 0
    static WinEventSystemHook   := 0
    static WinEventForegroundHook := 0
    static WinEventProc         := 0
    static WinEventCallback     := ""
    static EventProcessCallback := ""
    static PendingWindowEvents  := Map()
    static EventProcessScheduled := false
    static BadgeZOrderRetries    := Map()  ; hwnd -> bounded Z-order retry state

    ; -----------------------------------------------------------------------
    ; Lifecycle
    ; -----------------------------------------------------------------------

    ; Reads the persisted setting and picks up windows that were already
    ; pinned before the script started (or before the feature was enabled).
    static Init() {
        this.Enabled := AppState.AlwaysOnTopIndicator ? true : false
        this.Tracked := Map()
        this.TimerCallback := ""

        if this.Enabled {
            this.ScanTopmostWindows()
            this._EnsureWinEventHook()
        }
    }

    ; Tear everything down. Called on exit and when the feature is disabled.
    static Clear() {
        ; Stop receiving global window notifications before tearing down badge GUIs.
        this._StopWinEventHook()

        for hwnd, state in this.Tracked.Clone() {
            try {
                if IsObject(state.gui)
                    state.gui.Destroy()
            } catch {
            }
        }

        this.Tracked := Map()
        this.BadgeZOrderRetries := Map()
        this._StopTimer()
    }

    ; -----------------------------------------------------------------------
    ; Public API
    ; -----------------------------------------------------------------------

    static IsEnabled() => this.Enabled

    ; CapsLock + T entry point. Adds or removes the badge so the visible state
    ; always matches the window style that was just applied.
    static Refresh(hwnd := 0) {
        if !hwnd
            hwnd := WinExist("A")
        if !hwnd
            return

        if !this.Enabled
            return

        if this.IsTrackable(hwnd)
            this.Track(hwnd)
        else if this.Tracked.Has(hwnd)
            this.Untrack(hwnd)
    }

    ; Enable / disable at runtime (tray menu). Persists the choice.
    static SetEnabled(enabled) {
        enabled := enabled ? true : false

        if enabled == this.Enabled
            return

        this.Enabled := enabled
        AppState.AlwaysOnTopIndicator := enabled

        try ConfigManager.Save()

        if enabled {
            this.ScanTopmostWindows()
            this._EnsureWinEventHook()
        } else {
            this.Clear()
        }
    }

    ; One-shot discovery of already-pinned windows.
    static ScanTopmostWindows() {
        count := 0
        try {
            for hwnd in WinGetList() {
                if !this.IsTrackable(hwnd)
                    continue
                if this.Track(hwnd)
                    count++
            }
        } catch {
        }
        return count
    }

    ; Drop the topmost style and the badge together.
    static Unpin(hwnd) {
        if !hwnd
            return

        alive := false
        try
            alive := DllCall("user32\IsWindow", "ptr", hwnd, "int") != 0
        catch
            alive := false

        if alive {
            try
                WinSetAlwaysOnTop(0, "ahk_id " hwnd)
            catch {
            }
        }

        this.Untrack(hwnd)
    }

    ; hwnds currently showing a badge, for the tray sub-menu.
    static PinnedWindows() {
        result := []
        for hwnd, state in this.Tracked
            result.Push(hwnd)
        return result
    }

    ; Rebuild every badge after a palette change.
    static RefreshTheme() {
        if !this.Enabled
            return

        saved := []
        for hwnd, state in this.Tracked
            saved.Push(hwnd)

        this.Clear()

        for hwnd in saved {
            if this.IsTrackable(hwnd)
                this.Track(hwnd)
        }

        if this.Enabled
            this._EnsureWinEventHook()
    }

    ; -----------------------------------------------------------------------
    ; Tracking
    ; -----------------------------------------------------------------------

    ; A persistent badge belongs only to a real application window, not to
    ; taskbar thumbnails, utility popups, or other transient topmost surfaces.
    static IsTrackable(hwnd) {
        return this.IsBadgeCandidate(hwnd) && this.IsTopmost(hwnd)
    }

    ; WS_EX_TOPMOST is not enough to identify a user-pinnable application
    ; window: taskbar hover previews and popup/tool windows can carry it too.
    ; Restrict badges to standalone top-level application windows.
    static IsBadgeCandidate(hwnd) {
        if !hwnd || !WindowIsManageable(hwnd)
            return false

        className := ""
        try
            className := WinGetClass("ahk_id " hwnd)
        catch
            return false

        ; Windows creates these shell surfaces for taskbar / task-switcher previews.
        if className == "TaskListThumbnailWnd" || className == "MultitaskingViewFrame"
            return false

        try {
            style := DllCall(
                "user32\GetWindowLongPtrW",
                "Ptr", hwnd,
                "Int", -16, ; GWL_STYLE
                "Ptr"
            )
            exStyle := DllCall(
                "user32\GetWindowLongPtrW",
                "Ptr", hwnd,
                "Int", -20, ; GWL_EXSTYLE
                "Ptr"
            )

            ; Ignore child controls, tool windows, and no-activate overlays.
            if (style & 0x40000000) || (exStyle & (0x80 | 0x08000000))
                return false

            ; Owned popups include transient previews, menus, and utility dialogs.
            owner := DllCall("user32\GetWindow", "Ptr", hwnd, "UInt", 4, "Ptr") ; GW_OWNER
            if owner
                return false

            root := DllCall("user32\GetAncestor", "Ptr", hwnd, "UInt", 2, "Ptr") ; GA_ROOT
            if root != hwnd
                return false
        } catch {
            ; Failing to classify a window must not turn it into a badge target.
            return false
        }

        return true
    }

    static IsTopmost(hwnd) {
        try {
            exStyle := WinGetExStyle("ahk_id " hwnd)
            return (exStyle & 0x8) != 0
        } catch
            return false
    }

    static Track(hwnd) {
        if !hwnd
            return false

        if this.Tracked.Has(hwnd)
            return true

        state := this._CreateBadge(hwnd)
        if !IsObject(state)
            return false

        this.Tracked[hwnd] := state
        this._EnsureTimer()
        this._UpdateBadge(hwnd)
        return true
    }

    static Untrack(hwnd) {
        if !this.Tracked.Has(hwnd)
            return

        state := this.Tracked[hwnd]

        try {
            if IsObject(state.gui)
                state.gui.Destroy()
        } catch {
        }

        this.Tracked.Delete(hwnd)
        this._ClearBadgeZOrderRetry(hwnd)

        if this.Tracked.Count == 0
            this._StopTimer()
    }

    ; -----------------------------------------------------------------------
    ; Badge construction
    ; -----------------------------------------------------------------------

    static _CreateBadge(hwnd) {
        dpi := this.GetDpi(hwnd)
        scale := dpi / this.DefaultDpi
        size := Max(12, Round(this.BaseSize * scale))
        offset := Max(1, Round(this.BaseOffset * scale))

        try {
            ; Do not make this an owned popup: Windows can hide owned windows
            ; with their owner during minimize/restore transitions.
            badge := Gui(
                "-DPIScale +AlwaysOnTop -Caption +ToolWindow +Border"
                " +E0x20 +E0x08000000"
            )
        } catch {
            return ""
        }

        badge.BackColor := Theme.Primary
        badge.MarginX := 0
        badge.MarginY := 0

        ; Segoe UI Emoji renders the pin glyph as a coloured bitmap on every
        ; supported Windows build, which keeps the badge readable without a
        ; second colour to maintain.
        try {
            badge.SetFont("s11 c" Theme.OnPrimary, "Segoe UI Emoji")
            badge.Add("Text", "x0 y0 w" size " h" size " Center +0x200", "📌")
        } catch {
        }

        try {
            ThemeHelper.ApplyWindowTheme(badge.Hwnd)
            badge.Show("x-2000 y-2000 w" size " h" size " NoActivate")
        } catch {
            try badge.Destroy()
            return ""
        }

        return {
            gui: badge,
            x: -2000,
            y: -2000,
            size: size,
            offset: offset,
            visible: true,
            wasMinimized: false,
            transitionPhase: this.TRANSITION_NONE,
            transitionStartedAt: 0
        }
    }

    ; -----------------------------------------------------------------------
    ; Per-tick maintenance
    ; -----------------------------------------------------------------------

    static _EnsureTimer() {
        if IsObject(this.TimerCallback)
            return

        this.TimerCallback := ObjBindMethod(this, "_Tick")
        SetTimer(this.TimerCallback, this.UpdateInterval)
    }

    static _StopTimer() {
        if IsObject(this.TimerCallback) {
            SetTimer(this.TimerCallback, 0)
            this.TimerCallback := ""
        }
    }

    ; Subscribe to window-show notifications instead of polling every window.
    ; The hook stays active while the feature is enabled, even with no tracked
    ; badges, so a newly created HWND can be discovered when the app shows it.
    static _EnsureWinEventHook() {
        if !this.Enabled
            return false

        if this.WinEventHook && this.WinEventSystemHook && this.WinEventForegroundHook
            return true

        if !IsObject(this.WinEventCallback) {
            this.WinEventCallback := ObjBindMethod(this, "_OnWinEvent")

            try {
                this.WinEventProc := CallbackCreate(
                    this.WinEventCallback,
                    "Fast",
                    7
                )
            } catch {
                this.WinEventCallback := ""
                return false
            }
        }

        if !IsObject(this.EventProcessCallback)
            this.EventProcessCallback := ObjBindMethod(this, "_ProcessPendingWindowEvents")

        ; Object visibility events cover explicit hide/show calls.
        if !this.WinEventHook {
            try {
                this.WinEventHook := DllCall(
                    "user32\SetWinEventHook",
                    "UInt", this.EVENT_OBJECT_SHOW,
                    "UInt", this.EVENT_OBJECT_HIDE,
                    "Ptr", 0,
                    "Ptr", this.WinEventProc,
                    "UInt", 0,
                    "UInt", 0,
                    "UInt", 0,
                    "Ptr"
                )
            } catch {
                this.WinEventHook := 0
            }
        }

        ; Native minimize/restore has a dedicated system event pair. Listening
        ; to it avoids depending solely on the badge's frame-update timer.
        if !this.WinEventSystemHook {
            try {
                this.WinEventSystemHook := DllCall(
                    "user32\SetWinEventHook",
                    "UInt", this.EVENT_SYSTEM_MINIMIZESTART,
                    "UInt", this.EVENT_SYSTEM_MINIMIZEEND,
                    "Ptr", 0,
                    "Ptr", this.WinEventProc,
                    "UInt", 0,
                    "UInt", 0,
                    "UInt", 0,
                    "Ptr"
                )
            } catch {
                this.WinEventSystemHook := 0
            }
        }

        ; Taskbar-button restore can primarily surface as a foreground
        ; transition. Listen separately so a badge can be raised after Explorer
        ; changes the topmost-window Z-order while toggling the taskbar button.
        if !this.WinEventForegroundHook {
            try {
                this.WinEventForegroundHook := DllCall(
                    "user32\SetWinEventHook",
                    "UInt", this.EVENT_SYSTEM_FOREGROUND,
                    "UInt", this.EVENT_SYSTEM_FOREGROUND,
                    "Ptr", 0,
                    "Ptr", this.WinEventProc,
                    "UInt", 0,
                    "UInt", 0,
                    "UInt", 0,
                    "Ptr"
                )
            } catch {
                this.WinEventForegroundHook := 0
            }
        }

        if this.WinEventHook || this.WinEventSystemHook || this.WinEventForegroundHook
            return true

        if this.WinEventProc {
            try CallbackFree(this.WinEventProc)
            this.WinEventProc := 0
        }

        this.WinEventCallback := ""
        this.EventProcessCallback := ""
        return false
    }

    static _StopWinEventHook() {
        if IsObject(this.EventProcessCallback)
            try SetTimer(this.EventProcessCallback, 0)

        this.PendingWindowEvents := Map()
        this.EventProcessScheduled := false

        if this.WinEventHook {
            try DllCall(
                "user32\UnhookWinEvent",
                "Ptr", this.WinEventHook,
                "Int"
            )
            this.WinEventHook := 0
        }

        if this.WinEventSystemHook {
            try DllCall(
                "user32\UnhookWinEvent",
                "Ptr", this.WinEventSystemHook,
                "Int"
            )
            this.WinEventSystemHook := 0
        }

        if this.WinEventForegroundHook {
            try DllCall(
                "user32\UnhookWinEvent",
                "Ptr", this.WinEventForegroundHook,
                "Int"
            )
            this.WinEventForegroundHook := 0
        }

        if this.WinEventProc {
            try CallbackFree(this.WinEventProc)
            this.WinEventProc := 0
        }

        this.WinEventCallback := ""
        this.EventProcessCallback := ""
    }

    ; WinEventProc is deliberately lightweight: queue relevant window events
    ; and coalesce them into a short deferred pass outside the native callback.
    static _OnWinEvent(hook, event, hwnd, idObject, idChild, eventThread, eventTime) {
        if !this.Enabled || !hwnd || !IsObject(this.EventProcessCallback)
            return

        isObjectVisibilityEvent :=
            event == this.EVENT_OBJECT_SHOW || event == this.EVENT_OBJECT_HIDE
        isSystemMinimizeEvent :=
            event == this.EVENT_SYSTEM_MINIMIZESTART || event == this.EVENT_SYSTEM_MINIMIZEEND
        isForegroundEvent := event == this.EVENT_SYSTEM_FOREGROUND

        if !isObjectVisibilityEvent && !isSystemMinimizeEvent && !isForegroundEvent
            return

        ; Object events are emitted for child/accessibility objects too. Only
        ; use the top-level window's own show/hide events for discovery.
        if isObjectVisibilityEvent
            && (idObject != this.OBJID_WINDOW || idChild != this.CHILDID_SELF)
            return

        ; Latch the transition before deferring event processing. The 16 ms
        ; maintenance timer must not interpret a temporary WS_EX_TOPMOST change
        ; as an intentional unpin during the 50 ms event debounce window.
        if this.Tracked.Has(hwnd) {
            state := this.Tracked[hwnd]
            if event == this.EVENT_SYSTEM_MINIMIZESTART || event == this.EVENT_OBJECT_HIDE {
                state.wasMinimized := true
                state.transitionPhase := this.TRANSITION_MINIMIZING
                state.transitionStartedAt := A_TickCount
                this._ClearBadgeZOrderRetry(hwnd)
            } else if event == this.EVENT_SYSTEM_MINIMIZEEND || event == this.EVENT_OBJECT_SHOW {
                state.wasMinimized := true
                state.transitionPhase := this.TRANSITION_RESTORING
                state.transitionStartedAt := A_TickCount
            }
        }

        ; Keep the event kinds, not just the HWND. A single debounced batch can
        ; contain both minimize-start and minimize-end (or hide and show); losing
        ; that sequence would make the restore path indistinguishable from a
        ; normal topmost check.
        if !this.PendingWindowEvents.Has(hwnd) {
            this.PendingWindowEvents[hwnd] := {
                minimizeStart: false,
                minimizeEnd: false,
                hidden: false,
                shown: false,
                foreground: false
            }
        }

        eventState := this.PendingWindowEvents[hwnd]
        switch event {
            case this.EVENT_SYSTEM_MINIMIZESTART:
                eventState.minimizeStart := true
            case this.EVENT_SYSTEM_MINIMIZEEND:
                eventState.minimizeEnd := true
            case this.EVENT_OBJECT_HIDE:
                eventState.hidden := true
            case this.EVENT_OBJECT_SHOW:
                eventState.shown := true
            case this.EVENT_SYSTEM_FOREGROUND:
                eventState.foreground := true
        }

        if !this.EventProcessScheduled {
            this.EventProcessScheduled := true
            try SetTimer(this.EventProcessCallback, -this.EVENT_DEBOUNCE_MS)
        }
    }

    static _ProcessPendingWindowEvents(*) {
        this.EventProcessScheduled := false

        if !this.Enabled {
            this.PendingWindowEvents := Map()
            return
        }

        pending := this.PendingWindowEvents
        this.PendingWindowEvents := Map()

        for hwnd, eventState in pending {
            try {
                if this.Tracked.Has(hwnd) {
                    state := this.Tracked[hwnd]
                    restoreEvent := eventState.minimizeEnd || eventState.shown
                    retryZOrder := restoreEvent || eventState.foreground

                    ; Preserve the tracked pin during a minimize/hide transition.
                    ; A new restore/show event will start a fresh bounded retry.
                    if eventState.minimizeStart || eventState.hidden {
                        state.wasMinimized := true
                        if !restoreEvent {
                            state.transitionPhase := this.TRANSITION_MINIMIZING
                            if !state.transitionStartedAt
                                state.transitionStartedAt := A_TickCount
                        }
                        this._ClearBadgeZOrderRetry(hwnd)
                        this._SetBadgeVisible(hwnd, false)
                    }

                    ; Restore/show must explicitly enter the recovery path even
                    ; if start/hide and end/show were coalesced into one batch.
                    if restoreEvent && this.Tracked.Has(hwnd) {
                        state := this.Tracked[hwnd]
                        state.wasMinimized := true
                        state.transitionPhase := this.TRANSITION_RESTORING
                        state.transitionStartedAt := A_TickCount
                        this._UpdateBadge(hwnd)
                    }

                    ; The shell can still change Z-order after the foreground
                    ; notification. Reconcile the badge now, then let the
                    ; existing frame timer retry only this HWND for a short,
                    ; bounded period rather than raising it continuously.
                    if eventState.foreground && this.Tracked.Has(hwnd)
                        this._UpdateBadge(hwnd)

                    if retryZOrder && this.Tracked.Has(hwnd)
                        this._ScheduleBadgeZOrderRetries(hwnd)
                    continue
                }

                ; A newly visible replacement HWND can be discovered from its
                ; show/restore/foreground event, but only after passing the
                ; strict candidate and topmost filters.
                if (
                    (eventState.minimizeEnd || eventState.shown || eventState.foreground)
                    && this.IsTrackable(hwnd)
                ) {
                    this.Track(hwnd)
                    if this.Tracked.Has(hwnd)
                        this._ScheduleBadgeZOrderRetries(hwnd)
                }
            } catch {
            }
        }

        ; An event may have arrived during processing after the snapshot above.
        if this.PendingWindowEvents.Count && !this.EventProcessScheduled {
            this.EventProcessScheduled := true
            try SetTimer(this.EventProcessCallback, -this.EVENT_DEBOUNCE_MS)
        }
    }

    static _Tick(*) {
        if !this.Enabled || this.Tracked.Count == 0 {
            this._StopTimer()
            return
        }

        ; Clone first: _UpdateBadge() may delete from Tracked when a window was
        ; closed or unpinned from the outside.
        for hwnd, state in this.Tracked.Clone() {
            try {
                this._UpdateBadge(hwnd)
                this._ProcessBadgeZOrderRetry(hwnd)
            } catch {
            }
        }
    }

    static _UpdateBadge(hwnd) {
        if !this.Tracked.Has(hwnd)
            return

        if !WindowHandleAlive(hwnd) {
            this.Untrack(hwnd)
            return
        }

        state := this.Tracked[hwnd]
        minimized := false
        try
            minimized := WinGetMinMax("ahk_id " hwnd) == -1
        catch
            minimized := false

        ; Handle invisibility before checking any mutable window styles. Some
        ; applications change ownership / tool-window styles while hiding; that
        ; must not erase a pin we already verified for this live HWND.
        ; Minimized and hidden windows keep their tracked pin state. Hide the
        ; independent badge while the target is not on screen.
        if minimized || !WindowIsVisible(hwnd) {
            state.wasMinimized := true
            if state.transitionPhase != this.TRANSITION_RESTORING {
                state.transitionPhase := this.TRANSITION_MINIMIZING
                if !state.transitionStartedAt
                    state.transitionStartedAt := A_TickCount
                this._ClearBadgeZOrderRetry(hwnd)
            }
            ; A restore notification can precede the actual visible state.
            ; Keep its retry alive while waiting for the HWND to reappear.
            this._SetBadgeVisible(hwnd, false)
            return
        }

        ; A start/hide event may occasionally be cancelled or not followed by a
        ; matching end/show event. Bound that protection while the target stays
        ; visible so a stale transition cannot preserve an externally removed pin.
        if state.transitionPhase == this.TRANSITION_MINIMIZING
            && state.transitionStartedAt
            && A_TickCount - state.transitionStartedAt >= this.TransitionTimeoutMs {
            state.transitionPhase := this.TRANSITION_NONE
            state.transitionStartedAt := 0
            state.wasMinimized := false
        }

        ; Remember a restore phase that is being completed by this visible
        ; maintenance pass, even if an earlier bounded wait expired while the
        ; target was still minimized.
        restoringWindow := state.transitionPhase == this.TRANSITION_RESTORING

        ; Some applications / window managers drop WS_EX_TOPMOST on restore.
        ; The tracked pin is the source of truth across that transition, so
        ; restore topmost once before considering the badge stale. Outside a
        ; minimize/hidden cycle, an external unpin still removes the badge.
        if !this.IsTopmost(hwnd) {
            if !state.wasMinimized && state.transitionPhase == this.TRANSITION_NONE {
                this.Untrack(hwnd)
                return
            }

            try WinSetAlwaysOnTop(1, "ahk_id " hwnd)
            if !this.IsTopmost(hwnd) {
                this._SetBadgeVisible(hwnd, false)
                return
            }
        }

        x := 0
        y := 0
        w := 0
        h := 0
        try
            WinGetPos(&x, &y, &w, &h, "ahk_id " hwnd)
        catch {
            this.Untrack(hwnd)
            return
        }

        if w <= 0 || h <= 0 {
            this._SetBadgeVisible(hwnd, false)
            return
        }

        ; Keep the existing recovery contract: force recreation after a hide /
        ; minimize cycle, but let _EnsureBadgeWindow defer recreation while the
        ; minimize-start event has arrived before the target is actually hidden.
        if !this._EnsureBadgeWindow(hwnd, state.wasMinimized)
            return

        state := this.Tracked[hwnd]
        if state.transitionPhase == this.TRANSITION_RESTORING {
            state.wasMinimized := false
            state.transitionPhase := this.TRANSITION_NONE
            state.transitionStartedAt := 0
        } else if state.transitionPhase == this.TRANSITION_NONE {
            state.wasMinimized := false
        }
        offset := state.offset
        size := state.size

        targetX := x + offset
        targetY := y + offset

        ; Keep the badge fully on screen. Maximized windows report a rect that
        ; is inflated by the invisible resize border, so without this clamp the
        ; badge would hang off the top-left corner of the display.
        targetX := this._ClampToVirtualScreenX(targetX, size)
        targetY := this._ClampToVirtualScreenY(targetY, size)

        if targetX != state.x || targetY != state.y {
            try
                state.gui.Move(targetX, targetY)
            catch {
                this.Untrack(hwnd)
                return
            }
            state.x := targetX
            state.y := targetY
        }

        this._SetBadgeVisible(hwnd, true)

        ; If the target became visible after the retry window expired, start a
        ; fresh bounded Z-order settle window now that the target can participate
        ; in Z-order placement. This avoids relying on another foreground event.
        if restoringWindow
            this._ScheduleBadgeZOrderRetries(hwnd)
    }

    ; Place the detached badge immediately above its target in the current
    ; Z order. This preserves the order of unrelated topmost windows and never
    ; activates the badge.
    static _RaiseBadge(hwnd) {
        if !this.Tracked.Has(hwnd)
            return false

        state := this.Tracked[hwnd]
        badgeHwnd := 0
        try {
            if IsObject(state.gui)
                badgeHwnd := state.gui.Hwnd
        } catch {
        }

        if !badgeHwnd || !WindowHandleAlive(badgeHwnd)
            return false

        previousHwnd := 0
        try
            previousHwnd := DllCall(
                "user32\GetWindow",
                "Ptr", hwnd,
                "UInt", 3, ; GW_HWNDPREV
                "Ptr"
            )
        catch
            previousHwnd := 0

        ; If the badge already precedes the target, it is in the correct spot.
        if previousHwnd == badgeHwnd
            return true

        ; Inserting after the window currently above the target keeps this
        ; badge in the topmost band without jumping ahead of every topmost app.
        insertAfter := -1 ; HWND_TOPMOST fallback
        if previousHwnd && WindowHandleAlive(previousHwnd) && this.IsTopmost(previousHwnd)
            insertAfter := previousHwnd

        try {
            return DllCall(
                "user32\SetWindowPos",
                "Ptr", badgeHwnd,
                "Ptr", insertAfter,
                "Int", 0,
                "Int", 0,
                "Int", 0,
                "Int", 0,
                "UInt", 0x0001 | 0x0002 | 0x0010 | 0x0200 ; SWP_NOSIZE | SWP_NOMOVE | SWP_NOACTIVATE | SWP_NOOWNERZORDER
                ,
                "Int"
            ) != 0
        } catch {
            return false
        }
    }

    ; Map.Delete throws when a key is absent; cleanup paths can run before a
    ; retry has been scheduled, so make clearing idempotent.
    static _ClearBadgeZOrderRetry(hwnd) {
        if this.BadgeZOrderRetries.Has(hwnd)
            this.BadgeZOrderRetries.Delete(hwnd)
    }

    ; Begin a short retry window after restore/show/foreground events. The
    ; existing geometry timer drives retries, so no new timer runs in the idle
    ; state and no whole-desktop scan is introduced.
    static _ScheduleBadgeZOrderRetries(hwnd) {
        if !this.Tracked.Has(hwnd)
            return

        now := A_TickCount
        this.BadgeZOrderRetries[hwnd] := {
            attemptsRemaining: this.ZOrderRetryAttempts,
            nextAttemptAt: now,
            deadlineAt: now + this.TransitionTimeoutMs
        }
    }

    static _ProcessBadgeZOrderRetry(hwnd) {
        if !this.BadgeZOrderRetries.Has(hwnd)
            return

        if !this.Tracked.Has(hwnd) {
            this._ClearBadgeZOrderRetry(hwnd)
            return
        }

        retry := this.BadgeZOrderRetries[hwnd]
        now := A_TickCount
        if now < retry.nextAttemptAt
            return

        minimized := false
        try
            minimized := WinGetMinMax("ahk_id " hwnd) == -1
        catch
            minimized := false

        if minimized || !WindowIsVisible(hwnd) {
            state := this.Tracked[hwnd]
            if (
                state.transitionPhase == this.TRANSITION_RESTORING
                && now < retry.deadlineAt
            ) {
                ; Do not consume a Z-order attempt while Windows still reports
                ; the target minimized/hidden. Wait only until the bounded
                ; restore deadline; a later visible pass can perform the tries.
                retry.nextAttemptAt := now + this.ZOrderRetryIntervalMs
                return
            }

            this._ClearBadgeZOrderRetry(hwnd)
            return
        }

        ; A temporarily absent WS_EX_TOPMOST bit is part of the restore race,
        ; not proof that the user unpinned the window. _Tick() has just tried
        ; to restore the target's topmost style; keep the bounded retry alive
        ; while transition protection is active so it can place the badge after
        ; the target regains its expected style.
        if !this.IsTopmost(hwnd) {
            state := this.Tracked[hwnd]
            if !state.wasMinimized && state.transitionPhase == this.TRANSITION_NONE {
                this._ClearBadgeZOrderRetry(hwnd)
                return
            }

            retry.attemptsRemaining -= 1
            if retry.attemptsRemaining <= 0 {
                this._ClearBadgeZOrderRetry(hwnd)
                return
            }

            retry.nextAttemptAt := now + this.ZOrderRetryIntervalMs
            return
        }

        this._RaiseBadge(hwnd)
        retry.attemptsRemaining -= 1

        if retry.attemptsRemaining <= 0 {
            this._ClearBadgeZOrderRetry(hwnd)
            return
        }

        retry.nextAttemptAt := now + this.ZOrderRetryIntervalMs
    }

    static _EnsureBadgeWindow(hwnd, forceRecreate := false) {
        if !this.Tracked.Has(hwnd)
            return false

        state := this.Tracked[hwnd]
        badgeHwnd := 0
        try {
            if IsObject(state.gui)
                badgeHwnd := state.gui.Hwnd
        } catch {
        }

        if badgeHwnd && WindowHandleAlive(badgeHwnd) {
            ; EVENT_SYSTEM_MINIMIZESTART may precede actual native minimization.
            ; Do not destroy a still-visible badge in that lead-in, even though
            ; the caller has already latched wasMinimized for race protection.
            if !forceRecreate || state.transitionPhase == this.TRANSITION_MINIMIZING
                return true
        }

        ; Rebuild after every completed minimize / hide cycle so a stale popup
        ; cannot keep the indicator hidden after the target is restored.
        if IsObject(state.gui)
            try state.gui.Destroy()

        replacement := this._CreateBadge(hwnd)
        if !IsObject(replacement)
            return false

        replacement.wasMinimized := state.wasMinimized
        replacement.transitionPhase := state.transitionPhase
        replacement.transitionStartedAt := state.transitionStartedAt
        this.Tracked[hwnd] := replacement
        return true
    }

    static _SetBadgeVisible(hwnd, visible) {
        if !this.Tracked.Has(hwnd)
            return

        state := this.Tracked[hwnd]

        if !IsObject(state.gui)
            return

        ; The GUI can become natively hidden without the cached `visible` flag
        ; changing. Reconcile with Win32 before taking the fast path so a
        ; restored target always gets its badge back.
        nativeVisible := state.visible
        try
            nativeVisible := DllCall("user32\IsWindowVisible", "Ptr", state.gui.Hwnd, "Int") != 0
        catch
            nativeVisible := state.visible

        if state.visible == visible && nativeVisible == visible
            return

        try {
            if visible
                state.gui.Show("NoActivate")
            else
                state.gui.Hide()
            state.visible := visible
        } catch {
            ; Leave the cache unchanged so the next timer tick retries.
        }
    }

    ; -----------------------------------------------------------------------
    ; Geometry helpers
    ; -----------------------------------------------------------------------

    ; Virtual-screen bounds cover every monitor, so a window on a secondary
    ; display is clamped with the same code path as one on the primary.
    static _ClampToVirtualScreenX(value, size) {
        left := 0
        width := A_ScreenWidth

        try {
            left := SysGet(76)      ; SM_XVIRTUALSCREEN
            width := SysGet(78)     ; SM_CXVIRTUALSCREEN
        } catch {
        }

        maxValue := left + width - size
        if maxValue < left
            maxValue := left

        return Clamp(value, left, maxValue)
    }

    static _ClampToVirtualScreenY(value, size) {
        top := 0
        height := A_ScreenHeight

        try {
            top := SysGet(77)       ; SM_YVIRTUALSCREEN
            height := SysGet(79)    ; SM_CYVIRTUALSCREEN
        } catch {
        }

        maxValue := top + height - size
        if maxValue < top
            maxValue := top

        return Clamp(value, top, maxValue)
    }

    ; Per-window DPI (Windows 10 1607 and newer). Older builds have no
    ; GetDpiForWindow, so the DllCall fails and the 96 DPI default applies.
    static GetDpi(hwnd) {
        dpi := 0

        try
            dpi := DllCall("user32\GetDpiForWindow", "ptr", hwnd, "uint")
        catch
            dpi := 0

        if dpi < 48
            dpi := this.DefaultDpi

        return dpi
    }

    ; -----------------------------------------------------------------------
    ; Tray helpers
    ; -----------------------------------------------------------------------

    ; Capture the HWND in a zero-argument closure instead of binding directly
    ; to a class method. CustomMenu invokes submenu callbacks after closing and
    ; destroying their controls; this form preserves the handle independently
    ; of the menu event arguments.
    static MakeUnpinCallback(hwnd) {
        return ((*) => PinIndicator.UnpinFromMenu(hwnd))
    }

    ; Short label for the "pinned windows" sub-menu.
    static MenuLabel(hwnd) {
        title := ""

        try
            title := WinGetTitle("ahk_id " hwnd)
        catch
            title := ""

        if title == ""
            title := "#" hwnd

        ; The menu renderer truncates anyway, but trimming here keeps the
        ; ellipsis visible instead of clipping mid-glyph.
        if StrLen(title) > 44
            title := SubStr(title, 1, 43) "…"

        return title
    }

    static UnpinFromMenu(hwnd, *) {
        title := this.MenuLabel(hwnd)
        this.Unpin(hwnd)
        ShowToolTip(Lang("MSG_TOPMOST_WINDOW_UNPINNED", "Unpinned: {1}", title), 1800)
    }
}
