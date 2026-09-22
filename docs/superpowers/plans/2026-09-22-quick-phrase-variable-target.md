# Quick Phrase Variable Target Handoff Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans or superpowers:subagent-driven-development to implement this plan task-by-task.

**Goal:** Make Quick Phrase variable templates reliably deliver their completed text to the exact application/input position that was focused before Quick Phrase opened, while preserving compatibility fallbacks for custom controls.

**Architecture:** Move Quick Phrase target capture, validation, activation, focused-control restoration, and paste delivery into a dedicated QuickPhraseTarget component. The UI workflow owns only phrase selection and variable collection; it passes one captured target object through the transaction and never mutates the global AppState.TargetWindow used by unrelated paste features.

**Tech Stack:** AutoHotkey v2.0.28, native Win32 window/control APIs, existing Quick Phrase GUI and clipboard infrastructure, GitHub Actions on Windows.

**Spec:** docs/superpowers/plans/2026-09-22-quick-phrase-variable-target.md

## Global Constraints

- Quick Phrase must capture its destination before any Quick Phrase GUI becomes foreground.
- Selector, variable-input GUI, and OK/Cancel interactions must never replace the captured Quick Phrase destination.
- Fixed and variable Quick Phrases must use the same final delivery mechanism.
- The Quick Phrase implementation must not mutate AppState.TargetWindow.
- The original focused control should be restored when it still exists and belongs to the captured window.
- Custom controls which reject ControlFocus must fall back to window-level focus before Ctrl+V.
- A target window that no longer exists must fail deterministically rather than silently paste to another active window.
- The existing asynchronous clipboard restoration and sequence/generation protection must remain intact.
- Every commit must run the Windows regression workflow before the next implementation task proceeds.
- No merge operation is performed by the AI.

## Review Focus

- Variable-dialog close to target-window activation must use a condition-based success check rather than a fixed sleep.
- The captured control HWND must never be reused after it has been destroyed or after ownership changed.
- A failed target activation must never silently fall back to the currently active Quick Phrase GUI.
- Fixed and variable phrases must share exactly the same final target-delivery path.
- Existing normal clipboard/history paste behavior must remain unaffected by Quick Phrase target handling.

## Detailed Tasks

### Task 1: Define the failing target-handoff contract

**Files:**
- Modify: tests/QuickPhraseRegressionTests.ahk
- Create: tests/QuickPhraseTargetRegressionTests.ahk

**Interfaces:** Produces the assertions that Task 2's QuickPhraseTarget implementation must satisfy.

- [ ] Step 1: Add static assertions for the new target module contract.
Require UI/QuickPhraseGui.ahk to reference QuickPhraseTarget, require CapsLock-.ahk to include Core/QuickPhraseTarget.ahk, and require the old Quick Phrase delivery path to contain no AppState.TargetWindow assignment.

- [ ] Step 2: Add a Windows GUI target lifecycle test.
Create two native AHK GUI windows. Give the first GUI an Edit control, make that control focused, capture the target, activate the second GUI, then require QuickPhraseTarget.Activate() and QuickPhraseTarget.RestoreControlFocus() to restore the first GUI and its original Edit focus.

- [ ] Step 3: Add invalid-target cases.
Verify that a destroyed target window is rejected and a control whose root window does not equal the captured target is not treated as a valid focused-control destination.

- [ ] Step 4: Run the new tests before implementation.
Run AutoHotkey64.exe tests/QuickPhraseRegressionTests.ahk and AutoHotkey64.exe tests/QuickPhraseTargetRegressionTests.ahk. Expected: the new target tests fail because Core/QuickPhraseTarget.ahk and its API do not yet exist.

- [ ] Step 5: Commit.
Commit message: test(quick-phrase): define variable target handoff contract

### Task 2: Implement isolated Quick Phrase target handling

**Files:**
- Create: Core/QuickPhraseTarget.ahk
- Modify: CapsLock-.ahk
- Test: tests/QuickPhraseTargetRegressionTests.ahk

**Interfaces:**
- Consumes: raw foreground window state from WinExist(A) and optional focused control from ControlGetFocus().
- Produces: QuickPhraseTarget.Capture(), QuickPhraseTarget.IsWindowValid(target), QuickPhraseTarget.IsControlValid(target), QuickPhraseTarget.Activate(target), and QuickPhraseTarget.RestoreControlFocus(target).

- [ ] Step 1: Implement capture.
Capture() returns an object with window and control. window comes from WinExist(A); control comes from ControlGetFocus(ahk_id window) and becomes 0 when unavailable.

- [ ] Step 2: Implement window validation.
IsWindowValid(target) returns true only when target is an object, has a non-zero window HWND, and WinExist(ahk_id target.window) still resolves to that exact HWND.

- [ ] Step 3: Implement control ownership validation.
IsControlValid(target) requires a non-zero control HWND, WinExist(ahk_id target.control), and GetAncestor(control, GA_ROOT) equal to target.window.

- [ ] Step 4: Implement activation.
Activate(target, timeout := 1) calls WinActivate(ahk_id target.window) and then WinWaitActive(ahk_id target.window, , timeout). It returns false on timeout and never activates an unrelated current window as fallback.

- [ ] Step 5: Implement focused-control restoration.
RestoreControlFocus(target) returns false when IsControlValid(target) is false. Otherwise call ControlFocus(target.control, ahk_id target.window), then verify ControlGetFocus(ahk_id target.window) equals the captured control HWND. Return true only when the verification succeeds.

- [ ] Step 6: Run tests to verify green.
Run both target regression scripts. Expected: all assertions pass, including real GUI activation/focus restoration.

- [ ] Step 7: Commit.
Commit message: feat(quick-phrase): isolate target activation and focus restoration

### Task 3: Route Quick Phrase through the isolated target

**Files:**
- Modify: UI/QuickPhraseGui.ahk
- Test: tests/QuickPhraseRegressionTests.ahk
- Test: tests/QuickPhraseTargetRegressionTests.ahk

**Interfaces:**
- Consumes: QuickPhraseTarget.Capture() and validation/activation/focus APIs from Task 2.
- Produces: a Quick Phrase transaction that carries one immutable target object from hotkey entry through final delivery.

- [ ] Step 1: Capture the original target once.
Change QuickPhraseHandleHotkey() to call QuickPhraseTarget.Capture() before ShowQuickPhraseSelector(false) and save it in AppState.QuickPhrasePasteTarget.

- [ ] Step 2: Stop Quick Phrase from using the global paste target.
Remove every Quick Phrase assignment to AppState.TargetWindow, including the temporary assignment currently inside QuickPhrasePasteText().

- [ ] Step 3: Keep the transaction target through the variable dialog.
Pass the captured target object directly from QuickPhraseUseSelected() to QuickPhraseExecutePhrase(), then to QuickPhrasePasteText().

- [ ] Step 4: Add deterministic target validation before delivery.
Before clipboard mutation, verify the target window still exists. If it does not, return a target-unavailable result and do not attempt Ctrl+V.

- [ ] Step 5: Commit.
Commit message: refactor(quick-phrase): carry isolated target through transaction

### Task 4: Make final delivery race-resistant

**Files:**
- Modify: Core/QuickPhraseTarget.ahk
- Modify: UI/QuickPhraseGui.ahk
- Modify: tests/QuickPhraseTargetRegressionTests.ahk
- Modify: tests/QuickPhraseRegressionTests.ahk

**Interfaces:**
- Consumes: captured Quick Phrase target and completed text.
- Produces: deterministic final paste with activation verification and control-focus restoration fallback.

- [ ] Step 1: Add a delivery method.
Implement QuickPhraseTarget.DeliverPaste(target) using this order: activate the target; if activation fails, return a failure result; attempt RestoreControlFocus; send Ctrl+V; return a result containing success and whether control focus was restored.

- [ ] Step 2: Preserve window-level fallback.
When RestoreControlFocus() returns false because the control is missing or unsupported, keep the activated target window as the destination and issue normal Send(Ctrl+V).

- [ ] Step 3: Remove the fixed activation sleep from Quick Phrase delivery.
Quick Phrase target delivery must rely on WinWaitActive() as the activation condition. No Sleep(100) may be used as the activation-success test.

- [ ] Step 4: Keep clipboard transaction separate.
Leave ClipboardAll(), GetClipboardSequenceNumber(), QuickPhraseClipboardRestoreGeneration, and delayed clipboard restoration separate from target activation. The target module must never own clipboard backup state.

- [ ] Step 5: Add runtime delivery assertions.
The target test must activate a second GUI, call DeliverPaste() against the first GUI, and verify its original Edit control is focused after delivery.

- [ ] Step 6: Commit.
Commit message: fix(quick-phrase): synchronize final target handoff

### Task 5: Clarify failure reporting and strengthen regression coverage

**Files:**
- Modify: UI/QuickPhraseGui.ahk
- Modify: lang.csv
- Modify: tests/QuickPhraseRegressionTests.ahk
- Modify: .github/workflows/test.yml

**Interfaces:** Consumes QuickPhraseTarget.DeliverPaste() result object from Task 4 and produces explicit Quick Phrase error reporting and CI coverage.

- [ ] Step 1: Add dedicated target failure messages.
Add localization keys for original target window unavailable; target activation failed; Quick Phrase paste failed; original control unavailable but window fallback used.

- [ ] Step 2: Surface the correct error.
QuickPhrasePasteText() must distinguish target failure from clipboard failure and paste failure. It must not label an activation failure as No target window detected.

- [ ] Step 3: Add regression assertions.
Require the test suite to reject Quick Phrase code which assigns to AppState.TargetWindow and require QuickPhraseTarget.DeliverPaste() to be used by the final delivery path.

- [ ] Step 4: Run all Windows checks.
Run RegressionTests.ahk, CloudSyncRegressionTests.ahk, QuickPhraseRegressionTests.ahk, and QuickPhraseTargetRegressionTests.ahk. Expected: all pass.

- [ ] Step 5: Commit.
Commit message: test(quick-phrase): cover target failure diagnostics

### Task 6: Full-branch review and runtime validation gate

**Files:** Review all files changed by PR #83 relative to main.

- [ ] Step 1: Compare the complete PR against main.
Verify no unrelated modifications were introduced and inspect all changed files, not only the latest commits.

- [ ] Step 2: Verify final CI.
Require the latest Actions run to report successful Regression Tests, Cloud Sync regression tests, Quick Phrase regression tests, and Quick Phrase target runtime tests.

- [ ] Step 3: Perform static review.
Check that Quick Phrase never mutates AppState.TargetWindow; target capture occurs before GUI creation; variable GUI cannot overwrite the target; activation success is condition-based; focused-control restoration is validated; fallback is explicit; clipboard restoration remains independent; normal History/Paste flows are untouched.

- [ ] Step 4: Document manual Windows validation.
Test at minimum: Notepad/Edit control, VS Code text editor, Chromium browser input, Electron input, a standard {{text}} variable, {{etxt}} with multiple lines, multiple variables, repeated variables, cancellation, target application closed while variable dialog is open, and repeated CapsLock + Shift + P while variable dialog is open.

- [ ] Step 5: Submit final PR review.
Record the full-diff review and current CI status. Do not merge the PR.

## Commit/CI Gate

Each implementation task ends at a commit. After each commit: wait for the corresponding Windows Actions run; read the actual job result; if failed, return to root-cause investigation for that task; fix with a separate commit; wait for Actions again; only after success proceed to the next implementation task.

## Runtime Acceptance Contract

~~~text
original input focus
    ↓
CapsLock + Shift + P
    ↓
select variable phrase
    ↓
fill variables
    ↓
click OK
    ↓
Quick Phrase GUI closes
    ↓
original window becomes active
    ↓
original focused control is restored when possible
    ↓
completed text is pasted there
~~~

The CI source tests are necessary but not sufficient for this contract; the final manual Windows GUI sequence remains a required runtime gate.