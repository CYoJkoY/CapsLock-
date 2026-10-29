#Requires AutoHotkey v2.0

class ImageToolsGui {
    static Instance := 0
    static Paths := []
    static OperationValues := ["compress", "merge", "convert"]
    static AutoOutputDirectory := true
    static AutoFillInProgress := false

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

        myGui := Gui("+AlwaysOnTop -MaximizeBox", Lang("GUI_IMAGE_TOOLS_TITLE", "ImageMagick Image Tools"))
        ThemeHelper.StyleGui(myGui)
        ThemeHelper.AddTitle(myGui, Lang("GUI_IMAGE_TOOLS_TITLE", "ImageMagick Image Tools"), 590)
        ThemeHelper.AddSubtitle(myGui, Lang("GUI_IMAGE_TOOLS_SUBTITLE", "Compress, merge vertically, or convert images. Source files are kept unchanged."), 590)
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
            Lang("GUI_IMAGE_TOOLS_OPERATION_CONVERT", "Convert")
        ]
        operation := myGui.Add("DropDownList", "xm y+6 w180 Choose1 c" Theme.Text " Background" Theme.Control, operationLabels)
        format := myGui.Add("DropDownList", "x+10 yp w180 Choose1 c" Theme.Text " Background" Theme.Control, ["jpg", "png", "webp", "gif", "tiff", "bmp"])
        quality := myGui.Add("Edit", "x+10 yp w100 Number " ThemeHelper.GetEditOptions(), "85")
        ThemeHelper.StyleComboBox(operation)
        ThemeHelper.StyleComboBox(format)
        ThemeHelper.StyleEdit(quality)

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
        myGui.Status := status
        myGui.OnEvent("Escape", (*) => this.Close())
        myGui.OnEvent("Close", (*) => this.Close())
        addButton.OnEvent("Click", (*) => this.AddImages())
        removeButton.OnEvent("Click", (*) => this.RemoveSelected())
        clearButton.OnEvent("Click", (*) => this.ClearImages())
        browseButton.OnEvent("Click", (*) => this.BrowseOutputDirectory())
        runButton.OnEvent("Click", (*) => this.RunOperation())
        closeButton.OnEvent("Click", (*) => this.Close())
        outputDirectory.OnEvent("Change", (*) => this.OutputDirectoryChanged())

        this.Paths := []
        this.AutoOutputDirectory := true
        this.AutoFillInProgress := false
        this.Instance := myGui
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

        added := false
        for path in selected {
            if !FileExist(path) || InStr(FileExist(path), "D") {
                continue
            }
            if this._HasPath(path) {
                continue
            }
            this.Paths.Push(path)
            this.Instance.ImageList.Add(, path)
            added := true
        }
        if added {
            this._RefreshAutoOutputDirectory()
        }
        this.Instance.Status.Text := Lang("GUI_IMAGE_TOOLS_SELECTED", "{1} image(s) selected. Existing source files will not be modified.", this.Paths.Length)
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
        this.Instance.Status.Text := Lang("GUI_IMAGE_TOOLS_PROCESSING", "Processing {1} image(s)...", this.Paths.Length)
        try {
            result := ImageTools.Execute(this.Paths, operationName, outputFormat, qualityValue, selectedDirectory)
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
