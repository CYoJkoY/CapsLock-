#Requires AutoHotkey v2.0

; Injected ahead of the script under test by scripts\ci\Invoke-Ahk.ps1 (the
; /include switch). It makes an unattended run fail loudly instead of waiting
; for a dialog that nobody can click:
;
;   * load-time warnings (an unassigned global, unreachable code) are written
;     to stdout, with file and line, instead of opening a MsgBox - AutoHotkey's
;     default when a script has no #Warn directive;
;   * an uncaught runtime error is written to stderr and ends the process with
;     exit code 2 instead of opening the error dialog.
;
; Nothing here changes what the script does when it is started normally.
#Warn VarUnset, StdOut
#Warn Unreachable, StdOut

OnError(HeadlessUnhandledError)

HeadlessUnhandledError(err, mode) {
    text := "Unhandled error (" mode "): " err.Message
    try text .= "`n  What: " err.What
    try text .= "`n  File: " err.File " (line " err.Line ")"
    try text .= "`n" err.Stack
    try FileAppend(text "`n", "**", "UTF-8-RAW")
    ExitApp(2)
}
