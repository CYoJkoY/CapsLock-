#Requires AutoHotkey v2.0
#SingleInstance Off

; ---------------------------------------------------------------------------
; Headless functional check of the full-history window's paging and search.
;
; It runs the REAL RefreshFullHistoryList() / OnLoadMoreClicked() from
; History\FullHistoryGui.ahk against a real ListView in a window that is never
; shown, and edits the history through the real HistoryManager. That covers
; what the visual check was for: page sizes, "Load More", filtering, and that
; an edit made while the window is open invalidates the incremental cache.
; It cannot judge how the window looks.
;
; Run it through the wrapper (AutoHotkey is a GUI program, so a plain console
; launch neither waits for it nor shows its output):
;     .\scripts\ci\Invoke-Ahk.ps1 .\scripts\HistoryGuiPaging.ahk
;     .\scripts\ci\Invoke-Ahk.ps1 .\scripts\HistoryGuiPaging.ahk -ScriptArguments '-CSharp'
;
; Without -CSharp only the AHK backend is exercised. With -CSharp the pinned
; bridge and lib\CapsLockSharp.dll are required (absence is a failure), the same
; scenario also runs on the resident C# index, and both runs must produce
; byte-identical rows.
; ---------------------------------------------------------------------------

#Include *i ..\lib\ahk#\lib\ahk#.ahk
#Include ..\Config\Globals.ahk
#Include ..\Config\Encryption.ahk
#Include ..\Core\Services.ahk
#Include ..\Core\FileValidation.ahk
#Include ..\Core\FileOperations.ahk
#Include ..\History\HistoryStorage.ahk
#Include ..\History\FullHistoryGui.ahk

; FullHistoryGui.ahk also holds the code that builds the whole window and wires
; its click handlers (ThemeHelper, Lang, OnItemCheck ...). This test only drives
; the refresh path, so it does not load the rest of the application and the
; names that code mentions but never reaches here stay undefined on purpose.
#Warn VarUnset, Off

checks := 0
failures := 0

Check(condition, name) {
    global checks, failures
    checks++
    if !condition {
        failures++
        FileAppend("FAIL " name "`n", "*", "UTF-8-RAW")
    }
}

; Stand-ins for what the window code expects from the rest of the application.
; Lang() echoes its key and arguments so the status line can be asserted.
Lang(key, fallback := "", params*) {
    text := key
    for value in params
        text .= "|" value
    return text
}

class ThemeHelper {
}

PasteSelectedFromFullHistory(*) {
}

PasteSelectedFromFullHistoryText(*) {
}

; --- helpers -----------------------------------------------------------------

; Index 7 collapses whitespace in the preview, index 100 is longer than the
; 80-character preview, every third entry carries a search keyword.
MakeEntries(count) {
    texts := []
    loop count {
        if A_Index == 7
            texts.Push("multi`r`n`tline entry")
        else if A_Index == 100
            texts.Push("long " Repeat("x", 100) " end")
        else
            texts.Push("entry " A_Index (Mod(A_Index, 3) == 0 ? " fizz" : ""))
    }
    return texts
}

Repeat(text, count) {
    result := ""
    loop count
        result .= text
    return result
}

ReplaceHistory(texts, max := 10000) {
    AppState.History := []
    AppState.MaxHistory := max
    AppState.IgnoreNextClipChange := false
    for text in texts
        AppState.History.Push(Map("text", text, "time", "2026-10-02 13:45:00", "source", "test"))
    HistoryManager.Replaced()
}

; The same controls ShowFullHistoryGui creates, without theming or events.
BuildWindow() {
    g := Gui("+Resize")
    g.ListView := g.Add("ListView", "r12 w480 Checked Multi", ["#", "Content", "Time"])
    g.SearchBox := g.Add("Edit", "w300")
    g.StatusBar := g.Add("Text", "w300", "")
    g.chkSelectAll := g.Add("CheckBox", , "all")
    AppState.FullHistoryGui := g
    return g
}

; What the search box's Change handler does (it is a closure inside
; ShowFullHistoryGui, so it cannot be called from here).
Search(g, text) {
    g.SearchBox.Text := text
    AppState.MAX_FULL_HISTORY_DISPLAY := 50
    RefreshFullHistoryList()
}

Cell(g, row, column) {
    return g.ListView.GetText(row, column)
}

Rows(g) {
    lv := g.ListView
    text := ""
    loop lv.GetCount()
        text .= lv.GetText(A_Index, 1) "|" lv.GetText(A_Index, 2) "|" lv.GetText(A_Index, 3) "`n"
    return text "#" g.StatusBar.Text "`n"
}

; --- scenario ----------------------------------------------------------------

; Returns every row ever displayed, for the cross-backend comparison.
RunScenario(label) {
    ReplaceHistory(MakeEntries(130))
    g := BuildWindow()
    transcript := ""

    ; First page.
    AppState.MAX_FULL_HISTORY_DISPLAY := 50
    RefreshFullHistoryList()
    Check(g.ListView.GetCount() == 50, label ": first page shows 50 rows")
    Check(Cell(g, 1, 1) == "1" && Cell(g, 1, 2) == "entry 1" && Cell(g, 1, 3) == "13:45", label ": first row")
    Check(Cell(g, 7, 2) == "multi line entry", label ": preview collapses whitespace")
    Check(Cell(g, 50, 1) == "50", label ": last row of the first page")
    Check(g.StatusBar.Text == "GUI_FULL_STATUSBAR|130|50", label ": status line, first page")
    transcript .= Rows(g)

    ; Load More appends the next page without repeating rows.
    OnLoadMoreClicked(0, 0)
    Check(g.ListView.GetCount() == 100, label ": Load More adds a page")
    Check(Cell(g, 51, 1) == "51" && Cell(g, 100, 1) == "100", label ": appended rows follow in order")
    Check(StrLen(Cell(g, 100, 2)) == 81 && SubStr(Cell(g, 100, 2), -1) == "…", label ": long entry is cut to 80 + ellipsis")
    Check(g.displayedCount == 100, label ": displayed count tracks the page")
    transcript .= Rows(g)
    OnLoadMoreClicked(0, 0)
    Check(g.ListView.GetCount() == 130 && Cell(g, 130, 1) == "130", label ": last page is partial")
    OnLoadMoreClicked(0, 0)
    Check(g.ListView.GetCount() == 130, label ": Load More past the end adds nothing")
    Check(g.StatusBar.Text == "GUI_FULL_STATUSBAR|130|130", label ": status line, all rows")
    transcript .= Rows(g)

    ; Filtering: ASCII case-insensitive, restarts at one page.
    Search(g, "FIZZ")
    Check(g.ListView.GetCount() == 43, label ": filter keeps the 43 keyword entries")
    Check(Cell(g, 1, 1) == "3" && Cell(g, 43, 1) == "129", label ": filtered rows keep their history index")
    Check(g.StatusBar.Text == "GUI_FULL_STATUSBAR_FILTERED|43|43", label ": status line, filtered")
    transcript .= Rows(g)
    Search(g, "multi line")
    Check(g.ListView.GetCount() == 1 && Cell(g, 1, 1) == "7", label ": query matching only the collapsed preview")
    transcript .= Rows(g)
    Search(g, "no such text")
    Check(g.ListView.GetCount() == 0, label ": no matches")
    transcript .= Rows(g)

    ; A broad filter pages like the unfiltered list.
    Search(g, "entry")
    Check(g.ListView.GetCount() == 50, label ": broad filter shows one page")
    OnLoadMoreClicked(0, 0)
    Check(g.ListView.GetCount() == 100, label ": broad filter pages")
    transcript .= Rows(g)

    ; An edit made while the window is open must not be hidden by the cache.
    Search(g, "")
    OnLoadMoreClicked(0, 0)
    Check(g.ListView.GetCount() == 100, label ": two pages before the edit")
    HistoryManager.Delete(1)
    RefreshFullHistoryList(true)
    Check(Cell(g, 1, 2) == "entry 2" && g.ListView.GetCount() == 100, label ": delete invalidates the incremental cache")
    transcript .= Rows(g)
    HistoryManager.Add("fresh clip")
    RefreshFullHistoryList(true)
    Check(Cell(g, 1, 2) == "fresh clip" && Cell(g, 2, 2) == "entry 2", label ": add invalidates the incremental cache")
    transcript .= Rows(g)
    HistoryManager.Trim(60)
    RefreshFullHistoryList(true)
    Check(g.ListView.GetCount() == 60, label ": trim invalidates the incremental cache")
    Check(g.StatusBar.Text == "GUI_FULL_STATUSBAR|60|60", label ": status line after trim")
    transcript .= Rows(g)

    ; A search must see the edited history, not a stale snapshot.
    Search(g, "fresh")
    Check(g.ListView.GetCount() == 1 && Cell(g, 1, 1) == "1", label ": search sees the added clip")
    transcript .= Rows(g)

    AppState.FullHistoryGui := ""
    g.Destroy()
    return transcript
}

Main() {
    global checks, failures
    root := RegExReplace(A_ScriptDir, "\\scripts$", "")
    work := A_Temp "\CapsLockGuiTests-" DllCall("GetCurrentProcessId") "-" A_TickCount
    DirCreate(work)
    AppState.HistoryFile := work "\history.bin"
    Services.assemblyPath := root "\lib\CapsLockSharp.dll"
    Services.bridgePath := root "\lib\ahk#\lib\ahk#.bridge.dll"
    requireCSharp := false
    for arg in A_Args
        if arg == "-CSharp"
            requireCSharp := true

    try {
        AppState.ServiceBackend := "ahk"
        Services.Configure()
        ahkRows := RunScenario("AHK")
        Check(!Services.ready, "the AHK backend never boots the CLR for the history window")

        if requireCSharp {
            AppState.ServiceBackend := "csharp"
            Services.Configure()
            if !Services.Boot()
                throw Error("Required C# backend unavailable: " Services.reason)
            callsBefore := Services.calls
            csharpRows := RunScenario("C#")
            Check(Services.calls > callsBefore, "the C# window scenario really crossed the bridge")
            Check(!Services.tripped, "the C# window scenario did not silently fall back")
            Check(csharpRows == ahkRows, "AHK and C# backends display identical rows")
        }
    } catch as err {
        failures++
        FileAppend("FAIL unexpected error: " err.Message "`n" err.Stack "`n", "*", "UTF-8-RAW")
    } finally {
        if HistoryManager.saveTimer
            SetTimer(HistoryManager.saveTimer, 0)
        HistoryManager.savePending := false
        DirDelete(work, true)
    }
    FileAppend(checks " checks, " failures " failures`n", "*", "UTF-8-RAW")
    ExitApp(failures ? 1 : 0)
}

Main()
