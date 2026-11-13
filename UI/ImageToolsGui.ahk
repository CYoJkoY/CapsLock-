#Requires AutoHotkey v2.0

class ImageToolsGui {
    static Instance := 0
    static Paths := []
    static OperationValues := ["compress", "merge", "merge_horizontal", "merge_grid", "convert"]
    static AutoOutputDirectory := true
    static AutoFillInProgress := false
    ; The background pair survives a close so a chosen colour is not lost
    ; between runs; the name, grid count and operation reset with the panel.
    static BackgroundColor := "#FFFFFF"
    static BackgroundAlpha := 100

    static IsOpen() {
        if !IsObject(this.Instance) {
            return false
        }
        try {
            return WinExist("ahk_id " this.Instance.Hwnd) ? true : false
        } catch {
            return false
        }
    }

    static Toggle() {
        if this.IsOpen() {
            this.Close()
            return
        }
        this.Show()
    }

    static Show() {
        if this.IsOpen() {
            try {
                this.Instance.Show()
                WinActivate("ahk_id " this.Instance.Hwnd)
                return
            } catch {
            this.Instance := 0
            }
        }

        ; WS_EX_ACCEPTFILES lets the window receive the DropFiles event.
        myGui := Gui("-MaximizeBox +E0x00000010", Lang("GUI_IMAGE_TOOLS_TITLE", "ImageMagick Image Tools"))
        ThemeHelper.StyleGui(myGui)
        ThemeHelper.AddTitle(myGui, Lang("GUI_IMAGE_TOOLS_TITLE", "ImageMagick Image Tools"), 590)
        ThemeHelper.AddSubtitle(myGui, Lang("GUI_IMAGE_TOOLS_SUBTITLE", "Compress, merge vertically, horizontally or as a grid, or convert images. Drop images onto this window. Source files are kept unchanged."), 590)
        ThemeHelper.AddSeparator(myGui, 590)

        myGui.SetFont("s9 Bold c" Theme.Text, Theme.Font)
        myGui.Add("Text", "xm y+12 w590", Lang("GUI_IMAGE_TOOLS_INPUT", "Input images"))
        myGui.SetFont("s9 c" Theme.Text, Theme.Font)
        ; Source paths form a single-column list, so a header and grid are unnecessary.
        list := myGui.Add("ListView", "xm y+6 w590 h150 " ThemeHelper.GetLVOptionsPlain("-Hdr"), [Lang("GUI_IMAGE_TOOLS_SOURCE_FILE", "Source file")])
        list.ModifyCol(1, 574)
        ThemeHelper.StyleListView(list)

        addButton := ThemeHelper.AddButton(myGui, "xm y+8 w112 h32", Lang("GUI_IMAGE_TOOLS_ADD", "Add images..."), "secondary")
        removeButton := ThemeHelper.AddButton(myGui, "x+8 yp w112 h32", Lang("GUI_IMAGE_TOOLS_REMOVE", "Remove selected"), "secondary")
        clearButton := ThemeHelper.AddButton(myGui, "x+8 yp w80 h32", Lang("GUI_IMAGE_TOOLS_CLEAR", "Clear"), "secondary")

        myGui.SetFont("s9 Bold c" Theme.Text, Theme.Font)
        myGui.Add("Text", "xm y+16 w110", Lang("GUI_IMAGE_TOOLS_OPERATION", "Operation"))
        myGui.Add("Text", "x+10 yp w110", Lang("GUI_IMAGE_TOOLS_FORMAT", "Output format"))
        myGui.Add("Text", "x+10 yp w110", Lang("GUI_IMAGE_TOOLS_QUALITY", "Quality (10-100)"))
        myGui.SetFont("s9 c" Theme.Text, Theme.Font)
        operationLabels := [
            Lang("GUI_IMAGE_TOOLS_OPERATION_COMPRESS", "Compress"),
            Lang("GUI_IMAGE_TOOLS_OPERATION_MERGE", "Merge vertically"),
            Lang("GUI_IMAGE_TOOLS_OPERATION_MERGE_HORIZONTAL", "Merge horizontally"),
            Lang("GUI_IMAGE_TOOLS_OPERATION_MERGE_GRID", "Merge grid"),
            Lang("GUI_IMAGE_TOOLS_OPERATION_CONVERT", "Convert")
        ]
        operation := myGui.Add("DropDownList", "xm y+6 w180 Choose1 c" Theme.Text " Background" Theme.Control, operationLabels)
        format := myGui.Add("DropDownList", "x+10 yp w180 Choose1 c" Theme.Text " Background" Theme.Control, ["jpg", "png", "webp", "gif", "tiff", "bmp"])
        quality := myGui.Add("Edit", "x+10 yp w100 Number " ThemeHelper.GetEditOptions(), "85")
        ThemeHelper.StyleComboBox(operation)
        ThemeHelper.StyleComboBox(format)
        ThemeHelper.StyleEdit(quality)

        myGui.SetFont("s9 Bold c" Theme.Text, Theme.Font)
        myGui.Add("Text", "xm y+14 w130", Lang("GUI_IMAGE_TOOLS_GRID_COLUMNS", "Grid columns (1-20)"))
        myGui.Add("Text", "x+16 yp w130", Lang("GUI_IMAGE_TOOLS_BACKGROUND", "Merge background"))
        ; Keep the opacity caption above the slider it describes.
        myGui.Add("Text", "x368 yp w180", Lang("GUI_IMAGE_TOOLS_OPACITY", "Opacity"))
        myGui.SetFont("s9 c" Theme.Text, Theme.Font)
        gridColumns := myGui.Add("Edit", "xm y+6 w84 Number " ThemeHelper.GetEditOptions(), "2")
        ThemeHelper.StyleEdit(gridColumns)
        swatch := myGui.Add("Text", "x+16 yp w96 h26 Border Background" Theme.Control " Center", this.BackgroundColor)
        ThemeHelper.MarkSurface(swatch, this._SwatchTextColor(this.BackgroundColor), this._ThemeColor(this.BackgroundColor))
        colorButton := ThemeHelper.AddButton(myGui, "x+8 yp w132 h28", Lang("GUI_IMAGE_TOOLS_CHOOSE_COLOR", "Choose color..."), "secondary")
        alphaSlider := myGui.Add("Slider", "x+16 yp w180 Range0-100 ToolTip", this.BackgroundAlpha)
        alphaLabel := myGui.Add("Text", "x+8 yp+8 w44", this.BackgroundAlpha "%")

        myGui.SetFont("s9 Bold c" Theme.Text, Theme.Font)
        myGui.Add("Text", "xm y+14 w590", Lang("GUI_IMAGE_TOOLS_OUTPUT_NAME", "Output name (optional)"))
        myGui.SetFont("s9 c" Theme.Text, Theme.Font)
        outputName := myGui.Add("Edit", "xm y+6 w590 " ThemeHelper.GetEditOptions(), "")
        ThemeHelper.StyleEdit(outputName)

        myGui.SetFont("s9 Bold c" Theme.Text, Theme.Font)
        myGui.Add("Text", "xm y+14 w590", Lang("GUI_IMAGE_TOOLS_OUTPUT_FOLDER", "Output folder"))
        myGui.SetFont("s9 c" Theme.Text, Theme.Font)
        outputDirectory := myGui.Add("Edit", "xm y+6 w478 " ThemeHelper.GetEditOptions(), "")
        ThemeHelper.StyleEdit(outputDirectory)
        browseButton := ThemeHelper.AddButton(myGui, "x+8 yp w104 h30", Lang("GUI_IMAGE_TOOLS_BROWSE", "Browse..."), "secondary")

        status := myGui.Add("Edit", "xm y+12 w590 h72 ReadOnly VScroll Wrap " ThemeHelper.GetEditOptions(), Lang("GUI_IMAGE_TOOLS_STATUS_INITIAL", "Add one or more images and choose an output folder."))
        ThemeHelper.StyleEdit(status)
        runButton := ThemeHelper.AddButton(myGui, "xm y+4 w142 h36", Lang("GUI_IMAGE_TOOLS_RUN", "Run operation"), "primary")
        closeButton := ThemeHelper.AddButton(myGui, "x+8 yp w90 h36", Lang("GUI_IMAGE_TOOLS_CLOSE", "Close"), "secondary")

        myGui.ImageList := list
        myGui.Operation := operation
        myGui.Format := format
        myGui.Quality := quality
        myGui.OutputDirectory := outputDirectory
        myGui.OutputName := outputName
        myGui.GridColumns := gridColumns
        myGui.BackgroundSwatch := swatch
        myGui.ColorButton := colorButton
        myGui.AlphaSlider := alphaSlider
        myGui.AlphaLabel := alphaLabel
        myGui.Status := status
        myGui.OnEvent("Escape", (*) => this.Close())
        myGui.OnEvent("Close", (*) => this.Close())
        myGui.OnEvent("DropFiles", (gui, ctrl, files, x := "", y := "") => this.HandleDrop(files))
        addButton.OnEvent("Click", (*) => this.AddImages())
        removeButton.OnEvent("Click", (*) => this.RemoveSelected())
        clearButton.OnEvent("Click", (*) => this.ClearImages())
        browseButton.OnEvent("Click", (*) => this.BrowseOutputDirectory())
        colorButton.OnEvent("Click", (*) => this.ChooseBackgroundColor())
        alphaSlider.OnEvent("Change", (*) => this.UpdateAlphaLabel())
        operation.OnEvent("Change", (*) => this.SyncOperationControls())
        runButton.OnEvent("Click", (*) => this.RunOperation())
        closeButton.OnEvent("Click", (*) => this.Close())
        outputDirectory.OnEvent("Change", (*) => this.OutputDirectoryChanged())

        this.Paths := []
        this.AutoOutputDirectory := true
        this.AutoFillInProgress := false
        this.Instance := myGui
        this._SyncOperationControls()
        ThemeHelper.ApplyWindowTheme(myGui.Hwnd)
        myGui.Show("AutoSize Center")
    }

    static Close() {
        myGui := this.Instance
        this.Instance := 0
        this.Paths := []
        if IsObject(myGui) {
            try myGui.Destroy()
        }
    }

    static AddImages() {
        if !this.IsOpen() {
            return
        }

        selected := FileSelect(
            "M3",
            ,
            Lang("GUI_IMAGE_TOOLS_SELECT_IMAGES", "Select images"),
            Lang("GUI_IMAGE_TOOLS_FILE_FILTER", "Images (*.png; *.jpg; *.jpeg; *.webp; *.gif; *.tif; *.tiff; *.bmp)")
        )
        if !(selected is Array) || selected.Length == 0 {
            return
        }

        this._AddPaths(selected)
        this.Instance.Status.Text := Lang("GUI_IMAGE_TOOLS_SELECTED", "{1} image(s) selected. Existing source files will not be modified.", this.Paths.Length)
    }

    ; Files dropped on the panel go through the same filtering as the file
    ; picker. Only existing supported images are kept; folders and duplicates
    ; are counted as skipped so the status line explains what happened.
    static HandleDrop(files) {
        if !this.IsOpen() || !(files is Array) {
            return
        }
        counts := this._AddPaths(files)
        this.Instance.Status.Text := Lang("GUI_IMAGE_TOOLS_DROP_SUMMARY", "Added {1}; skipped {2}.", counts.added, counts.skipped)
    }

    static _AddPaths(items) {
        added := 0
        skipped := 0
        for item in items {
            if !(item is String) || !this._IsSupportedImagePath(item) {
                skipped += 1
                continue
            }
            if this._HasPath(item) {
                skipped += 1
                continue
            }
            this.Paths.Push(item)
            this.Instance.ImageList.Add(, item)
            added += 1
        }
        if (added > 0) {
            this._RefreshAutoOutputDirectory()
        }
        return { added: added, skipped: skipped }
    }

    static _IsSupportedImagePath(path) {
        attributes := FileExist(path)
        if (attributes == "" || InStr(attributes, "D")) {
            return false
        }

        SplitPath(path, , , &extension)
        extension := StrLower(extension)
        for format in ImageTools.SupportedFormats {
            if (extension == format) {
                return true
            }
        }
        return false
    }

    static RemoveSelected() {
        if !this.IsOpen() {
            return
        }
        list := this.Instance.ImageList
        rows := []
        row := 0
        while row := list.GetNext(row, "Selected")
            rows.Push(row)
        if rows.Length == 0 {
            row := list.GetNext(0, "Focused")
            if row
                rows.Push(row)
        }
        if rows.Length == 0 {
            this.Instance.Status.Text := Lang("GUI_IMAGE_TOOLS_SELECT_REMOVE", "Select an image to remove from the list.")
            return
        }
        Loop rows.Length {
            row := rows[rows.Length - A_Index + 1]
            list.GetText(&selectedPath, row, 1)
            list.Delete(row)
            this._RemovePath(selectedPath)
        }
        this._RefreshAutoOutputDirectory()
        this.Instance.Status.Text := Lang("GUI_IMAGE_TOOLS_COUNT", "{1} image(s) selected.", this.Paths.Length)
    }

    static ClearImages() {
        if !this.IsOpen() {
            return
        }
        this.Paths := []
        this.Instance.ImageList.Delete()
        this._RefreshAutoOutputDirectory()
        this.Instance.Status.Text := Lang("GUI_IMAGE_TOOLS_LIST_CLEARED", "Image list cleared.")
    }

    static BrowseOutputDirectory() {
        if !this.IsOpen() {
            return
        }
        selectedDirectory := DirSelect("", 1, Lang("GUI_IMAGE_TOOLS_OUTPUT_FOLDER_SELECT", "Select output folder"))
        if (selectedDirectory != "") {
            this.AutoOutputDirectory := false
            this._SetOutputDirectory(selectedDirectory)
        }
    }

    static OutputDirectoryChanged() {
        if this.AutoFillInProgress
            return
        this.AutoOutputDirectory := false
    }

    static RunOperation() {
        if !this.IsOpen() {
            return
        }
        if (this.Paths.Length == 0) {
            this.Instance.Status.Text := Lang("GUI_IMAGE_TOOLS_ADD_REQUIRED", "Add at least one image before running an operation.")
            return
        }

        selectedDirectory := Trim(this.Instance.OutputDirectory.Value)
        if (selectedDirectory == "" || !DirExist(selectedDirectory)) {
            this.Instance.Status.Text := Lang("GUI_IMAGE_TOOLS_OUTPUT_REQUIRED", "Choose an existing output folder first.")
            return
        }

        qualityText := Trim(this.Instance.Quality.Value)
        if (qualityText == "" || !IsNumber(qualityText)) {
            this.Instance.Status.Text := Lang("GUI_IMAGE_TOOLS_QUALITY_REQUIRED", "Enter an image quality from 10 to 100.")
            return
        }
        qualityValue := Max(10, Min(100, Round(qualityText)))
        this.Instance.Quality.Value := qualityValue

        operationName := this._GetOperationValue(this.Instance.Operation.Value)
        outputFormat := this.Instance.Format.Text
        if (operationName == "") {
            this.Instance.Status.Text := Lang("GUI_IMAGE_TOOLS_OPERATION_REQUIRED", "Choose an operation first.")
            return
        }

        options := { Name: Trim(this.Instance.OutputName.Value) }
        if this._IsMergeOperation(operationName) {
            options.Background := this._ComposeBackground()
            if (operationName == "merge_grid") {
                columnsText := Trim(this.Instance.GridColumns.Value)
                if (columnsText == "" || !IsNumber(columnsText)) {
                    this.Instance.Status.Text := Lang("GUI_IMAGE_TOOLS_GRID_INVALID", "Enter whole grid columns from 1 to 20.")
                    return
                }
                columns := Round(columnsText)
                if (columns < 1 || columns > 20) {
                    this.Instance.Status.Text := Lang("GUI_IMAGE_TOOLS_GRID_INVALID", "Enter whole grid columns from 1 to 20.")
                    return
                }
                this.Instance.GridColumns.Value := columns
                options.GridColumns := columns
            }
        }

        this.Instance.Status.Text := Lang("GUI_IMAGE_TOOLS_PROCESSING", "Processing {1} image(s)...", this.Paths.Length)
        try {
            result := ImageTools.Execute(this.Paths, operationName, outputFormat, qualityValue, selectedDirectory, options)
        } catch as err {
            detail := Trim(err.Message)
            if (detail == "") {
                detail := Lang("GUI_IMAGE_TOOLS_NO_ERROR_DETAILS", "No additional error details were provided.")
            }
            this.Instance.Status.Text := Lang("GUI_IMAGE_TOOLS_PROCESS_FAILED", "Could not process images: {1}", detail)
            return
        }

        summary := Lang("GUI_IMAGE_TOOLS_SUMMARY", "{1} succeeded, {2} failed.", result.succeeded, result.failed)
        if (result.errors.Length > 0) {
            summary .= "`n" this._JoinLines(result.errors)
        } else if (result.outputs.Length > 0) {
            summary .= "`n" Lang("GUI_IMAGE_TOOLS_CREATED", "Created: {1}", this._JoinLines(result.outputs))
        }
        this.Instance.Status.Value := summary
    }

    static _GetOperationValue(selectedIndex) {
        if !IsNumber(selectedIndex)
            return ""
        selectedIndex := Round(selectedIndex)
        if (selectedIndex < 1 || selectedIndex > this.OperationValues.Length)
            return ""
        return this.OperationValues[selectedIndex]
    }

    static _IsMergeOperation(operation) {
        return operation == "merge" || operation == "merge_horizontal" || operation == "merge_grid"
    }

    ; Alpha is kept as a percentage for the slider and converted to the byte
    ; the #RRGGBBAA colour needs; 100% therefore reaches FF exactly.
    static _ComposeBackground() {
        alpha := Max(0, Min(100, Round(this.Instance.AlphaSlider.Value)))
        ; Dividing first keeps 25, 50 and 75 exact instead of one byte low.
        return this.BackgroundColor Format("{:02X}", Round(alpha / 100 * 255))
    }

    ; Theme colours are 0xRRGGBB strings and the swatch stores #RRGGBB, so the
    ; two forms are converted at the boundary and nowhere else.
    static _ThemeColor(color) {
        return "0x" SubStr(color, 2, 6)
    }

    static _SwatchTextColor(color) {
        red := Integer("0x" SubStr(color, 2, 2))
        green := Integer("0x" SubStr(color, 4, 2))
        blue := Integer("0x" SubStr(color, 6, 2))
        luminance := 0.299 * red + 0.587 * green + 0.114 * blue
        return (luminance >= 140) ? "0x202124" : "0xE8EAED"
    }

    ; COLORREF stores bytes as BGR, the opposite of the hexadecimal form.
    static _ToColorRef(color) {
        red := Integer("0x" SubStr(color, 2, 2))
        green := Integer("0x" SubStr(color, 4, 2))
        blue := Integer("0x" SubStr(color, 6, 2))
        return (blue << 16) | (green << 8) | red
    }

    static _FromColorRef(value) {
        return Format("#{:02X}{:02X}{:02X}", value & 0xFF, (value >> 8) & 0xFF, (value >> 16) & 0xFF)
    }

    ; The native picker covers the RGB choice; alpha stays on its own slider
    ; because ChooseColorW has no transparency support.
    static ChooseBackgroundColor() {
        if !this.IsOpen()
            return

        static CC_RGBINIT := 0x00000001
        static CC_FULLOPEN := 0x00000002
        static CC_ANYCOLOR := 0x00000100
        static DIALOG_SIZE := 72

        ; The dialog keeps the 16 custom colour slots for later picks, so the
        ; buffer must live for the whole session rather than one call.
        static customColors := Buffer(64, 0)
        dialog := Buffer(DIALOG_SIZE, 0)
        NumPut("UInt", DIALOG_SIZE, dialog, 0)
        NumPut("Ptr", this.Instance.Hwnd, dialog, 8)
        NumPut("UInt", this._ToColorRef(this.BackgroundColor), dialog, 24)
        NumPut("Ptr", customColors.Ptr, dialog, 32)
        NumPut("UInt", CC_RGBINIT | CC_FULLOPEN | CC_ANYCOLOR, dialog, 40)

        accepted := DllCall("comdlg32\ChooseColorW", "Ptr", dialog, "Int")
        if !accepted
            return

        this.BackgroundColor := this._FromColorRef(NumGet(dialog, 24, "UInt"))
        this.UpdateSwatch()
    }

    static UpdateSwatch() {
        swatch := this.Instance.BackgroundSwatch
        swatch.Text := this.BackgroundColor
        ThemeHelper.MarkSurface(swatch, this._SwatchTextColor(this.BackgroundColor), this._ThemeColor(this.BackgroundColor))
        swatch.Redraw()
    }

    static UpdateAlphaLabel() {
        value := Round(this.Instance.AlphaSlider.Value)
        this.BackgroundAlpha := value
        this.Instance.AlphaLabel.Text := value "%"
    }

    ; Only the controls that affect the current operation stay active, so the
    ; grid count cannot look relevant to a compress run and vice versa.
    static _SyncOperationControls() {
        if !this.IsOpen()
            return

        operationName := this._GetOperationValue(this.Instance.Operation.Value)
        isMerge := this._IsMergeOperation(operationName)
        this.Instance.GridColumns.Enabled := (operationName == "merge_grid")
        this.Instance.BackgroundSwatch.Enabled := isMerge
        this.Instance.ColorButton.Enabled := isMerge
        this.Instance.AlphaSlider.Enabled := isMerge
        this.Instance.AlphaLabel.Enabled := isMerge
    }

    static _RefreshAutoOutputDirectory() {
        if !this.AutoOutputDirectory
            return
        this._SetOutputDirectory(ImageTools.DefaultOutputDirectory(this.Paths))
    }

    static _SetOutputDirectory(value) {
        this.AutoFillInProgress := true
        try {
            this.Instance.OutputDirectory.Value := value
        } finally {
            this.AutoFillInProgress := false
        }
    }

    static _HasPath(candidate) {
        for path in this.Paths {
            if (StrLower(path) == StrLower(candidate)) {
                return true
            }
        }
        return false
    }

    static _RemovePath(target) {
        for index, path in this.Paths {
            if (StrLower(path) == StrLower(target)) {
                this.Paths.RemoveAt(index)
                return
            }
        }
    }

    static _JoinLines(items) {
        text := ""
        for item in items {
            if (text != "") {
                text .= "`n"
            }
            text .= item
        }
        return text
    }
}
