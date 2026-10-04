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
;   * The badge is owned by the pinned window, so it always stays above it in
;     the z-order and is torn down together with it.
; ---------------------------------------------------------------------------
class PinIndicator {
    ; --- Tunables ---
    static UpdateInterval := 16        ; near-frame updates keep the badge attached while dragging
    static BaseSize       := 22        ; badge edge length at 96 DPI
    static BaseOffset     := 4         ; gap from the window corner at 96 DPI
    static DefaultDpi     := 96

    ; --- Runtime state ---
    static Enabled        := true
    static Tracked        := Map()     ; hwnd -> badge geometry, visibility, and restore state
    static TimerCallback  := ""

    ; -----------------------------------------------------------------------
    ; Lifecycle
    ; -----------------------------------------------------------------------

    ; Reads the persisted setting and picks up windows that were already
    ; pinned before the script started (or before the feature was enabled).
    static Init() {
        this.Enabled := AppState.AlwaysOnTopIndicator ? true : false
        this.Tracked := Map()
        this.TimerCallback := ""

        if this.Enabled
            this.ScanTopmostWindows()
    }

    ; Tear everything down. Called on exit and when the feature is disabled.
    static Clear() {
        for hwnd, state in this.Tracked.Clone() {
            try {
                if IsObject(state.gui)
                    state.gui.Destroy()
            } catch {
            }
        }

        this.Tracked := Map()
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

        if enabled
            this.ScanTopmostWindows()
        else
            this.Clear()
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
    }

    ; -----------------------------------------------------------------------
    ; Tracking
    ; -----------------------------------------------------------------------

    ; A window gets a badge when it is a live, manageable, topmost window.
    ; WindowIsManageable() already excludes the shell surfaces and every
    ; window that belongs to CapsLock- itself.
    static IsTrackable(hwnd) {
        if !hwnd
            return false

        if !WindowIsManageable(hwnd)
            return false

        return this.IsTopmost(hwnd)
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
            badge := Gui(
                "-DPIScale +AlwaysOnTop -Caption +ToolWindow +Border"
                " +E0x20 +E0x08000000 +Owner" hwnd
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
            wasMinimized: false
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

    static _Tick(*) {
        if !this.Enabled || this.Tracked.Count == 0 {
            this._StopTimer()
            return
        }

        ; Clone first: _UpdateBadge() may delete from Tracked when a window was
        ; closed or unpinned from the outside.
        for hwnd, state in this.Tracked.Clone() {
            try
                this._UpdateBadge(hwnd)
            catch {
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

        ; Minimized and hidden windows keep their tracked pin state. The owner
        ; may also hide or destroy its owned badge while it is not on screen.
        if minimized || !WindowIsVisible(hwnd) {
            state.wasMinimized := true
            this._SetBadgeVisible(hwnd, false)
            return
        }

        ; Some applications / window managers drop WS_EX_TOPMOST on restore.
        ; The tracked pin is the source of truth across that transition, so
        ; restore topmost once before considering the badge stale. Outside a
        ; minimize/hidden cycle, an external unpin still removes the badge.
        if !this.IsTopmost(hwnd) {
            if !state.wasMinimized {
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

        if !this._EnsureBadgeWindow(hwnd, state.wasMinimized)
            return

        state := this.Tracked[hwnd]
        state.wasMinimized := false
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

        if !forceRecreate && badgeHwnd && WindowHandleAlive(badgeHwnd)
            return true

        ; Rebuild after every minimize / hide cycle, even if Windows leaves the
        ; owned popup HWND alive but non-visible after restoring its owner.
        if IsObject(state.gui)
            try state.gui.Destroy()

        replacement := this._CreateBadge(hwnd)
        if !IsObject(replacement)
            return false

        replacement.wasMinimized := state.wasMinimized
        this.Tracked[hwnd] := replacement
        return true
    }

    static _SetBadgeVisible(hwnd, visible) {
        if !this.Tracked.Has(hwnd)
            return

        state := this.Tracked[hwnd]

        if !IsObject(state.gui)
            return

        ; The badge is an owned popup. Windows can hide it automatically when
        ; its owner is minimized, without updating this class's cached `visible`
        ; flag. Reconcile against the native visibility before taking the fast
        ; path, so a restored owner always gets its badge back.
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
