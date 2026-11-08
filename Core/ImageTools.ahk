#Requires AutoHotkey v2.0

class ImageTools {
    static SupportedFormats := ["jpg", "jpeg", "png", "webp", "gif", "tif", "tiff", "bmp"]

    static DefaultOutputDirectory(paths) {
        if !(paths is Array)
            return ""

        for path in paths {
            if !(path is String)
                continue

            normalized := Trim(path)
            if (normalized == "")
                continue

            SplitPath(normalized, , &directory)
            if (directory != "")
                return directory
        }

        return ""
    }

    static Execute(paths, operation, outputFormat, quality, outputDirectory, options := "") {
        result := { succeeded: 0, failed: 0, outputs: [], errors: [] }

        if !(paths is Array) {
            return this._Fail(result, "Input paths must be an array.")
        }
        if (paths.Length == 0) {
            return this._Fail(result, "No input image paths were provided.")
        }
        if !(operation is String) || !this._IsSupportedOperation(operation) {
            return this._Fail(result, "Unsupported operation. Use compress, merge, merge_horizontal, merge_grid, or convert.")
        }

        outputFormat := StrLower(Trim(String(outputFormat)))
        if !this._IsSupportedFormat(outputFormat) {
            return this._Fail(result, "Unsupported output format. Use jpg, png, webp, gif, tiff, or bmp.")
        }

        if !IsNumber(quality) {
            return this._Fail(result, "Quality must be a number from 10 to 100.")
        }
        quality := Max(10, Min(100, Round(quality)))

        exe := Trim(String(AppState.ImageMagickExe))
        if (exe == "" || !FileExist(exe) || InStr(FileExist(exe), "D")) {
            return this._Fail(result, "ImageMagick executable is not configured or is invalid: " (exe == "" ? "(empty)" : exe))
        }

        outputDirectory := Trim(String(outputDirectory))
        if (outputDirectory == "" || !DirExist(outputDirectory)) {
            return this._Fail(result, "Output directory does not exist: " (outputDirectory == "" ? "(empty)" : outputDirectory))
        }

        outputName := ""
        mergeBackground := "#FFFFFF"
        gridColumns := 2
        if IsObject(options) {
            if options.HasProp("Name") {
                if !(options.Name is String) {
                    return this._Fail(result, "Output name must be text.")
                }
                outputName := this.SanitizeOutputName(options.Name)
            }
            if options.HasProp("Background") {
                try {
                    mergeBackground := this.NormalizeBackground(options.Background)
                } catch as err {
                    return this._Fail(result, "Invalid merge background: " err.Message)
                }
            }
            if options.HasProp("GridColumns") {
                if !IsNumber(options.GridColumns) {
                    return this._Fail(result, "Grid columns must be a whole number from 1 to 20.")
                }
                gridColumns := Round(options.GridColumns)
                if (gridColumns < 1 || gridColumns > 20) {
                    return this._Fail(result, "Grid columns must be a whole number from 1 to 20.")
                }
            }
        } else if (options != "") {
            return this._Fail(result, "Options must be an object.")
        }

        validPaths := []
        for path in paths {
            if !(path is String) || Trim(path) == "" {
                result.failed += 1
                result.errors.Push("Invalid input path: " (path is String ? "(empty)" : "(not a string)"))
                continue
            }

            path := Trim(path)
            attributes := FileExist(path)
            if (attributes == "" || InStr(attributes, "D")) {
                result.failed += 1
                result.errors.Push("Input file does not exist or is not a file: " path)
                continue
            }
            validPaths.Push(path)
        }

        isMerge := (operation == "merge" || operation == "merge_horizontal" || operation == "merge_grid")
        if (isMerge && result.failed > 0) {
            return result
        }
        if (isMerge && validPaths.Length < 2) {
            return this._Fail(result, "Select at least two valid images to combine.")
        }

        if isMerge {
            this._Merge(validPaths, exe, operation, outputFormat, quality, outputDirectory, outputName, mergeBackground, gridColumns, result)
            return result
        }

        for index, path in validPaths {
            this._ProcessOne(path, index, validPaths.Length, exe, operation, outputFormat, quality, outputDirectory, outputName, result)
        }
        return result
    }

    static _ProcessOne(path, index, total, exe, operation, outputFormat, quality, outputDirectory, outputName, result) {
        SplitPath(path, , , , &nameWithoutExtension)
        if (outputName != "") {
            baseName := (total == 1) ? outputName : outputName "_" index
        } else {
            suffix := operation == "compress" ? "_compressed" : "_converted"
            baseName := nameWithoutExtension suffix
        }
        if (StrLower(path) == StrLower(outputDirectory "\" baseName "." outputFormat))
            baseName .= "_" operation
        outputPath := this._UniqueOutputPath(outputDirectory, baseName, outputFormat)

        arguments := this._QuoteArgument(exe) " " this._QuoteArgument(path)
        if (outputFormat == "jpg" || outputFormat == "jpeg") {
            arguments .= " -background white -alpha remove"
        }
        arguments .= " -strip -quality " quality " " this._QuoteArgument(outputPath)
        this._Run(arguments, outputPath, path, result)
    }

    static _Merge(paths, exe, operation, outputFormat, quality, outputDirectory, outputName, background, columns, result) {
        baseName := (outputName != "") ? outputName : "merged_" FormatTime(, "yyyyMMdd_HHmmss")
        outputPath := this._UniqueOutputPath(outputDirectory, baseName, outputFormat)

        ; JPEG has no alpha channel, so padding falls back to the RGB part and
        ; the merged canvas is flattened after the append.
        isJpeg := (outputFormat == "jpg" || outputFormat == "jpeg")
        mergeBackground := isJpeg ? SubStr(background, 1, 7) : background
        arguments := this._QuoteArgument(exe) " -background " this._QuoteArgument(mergeBackground)
        if (operation == "merge_grid") {
            arguments .= this._GridGroups(paths, columns)
            arguments .= " -append"
        } else {
            for path in paths {
                arguments .= " " this._QuoteArgument(path)
            }
            arguments .= (operation == "merge_horizontal") ? " +append" : " -append"
        }
        if isJpeg {
            arguments .= " -alpha remove"
        }
        arguments .= " -strip -quality " quality " " this._QuoteArgument(outputPath)
        this._Run(arguments, outputPath, operation, result)
    }

    ; Emits one parenthesized group per grid row so ImageMagick appends each
    ; row horizontally and then stacks the rows vertically.
    static _GridGroups(paths, columns) {
        rows := this.GridRowSizes(paths.Length, columns)
        arguments := ""
        index := 1
        for count in rows {
            arguments .= " ("
            Loop count {
                arguments .= " " this._QuoteArgument(paths[index])
                index += 1
            }
            arguments .= " +append )"
        }
        return arguments
    }

    static _Run(arguments, outputPath, sourcePath, result) {
        try {
            exitCode := RunWait(arguments, , "Hide")
            if (exitCode != 0) {
                this._DeleteOutput(outputPath)
                result.failed += 1
                result.errors.Push("ImageMagick failed for " sourcePath " (exit code " exitCode ").")
                return
            }
        } catch as err {
            this._DeleteOutput(outputPath)
            result.failed += 1
            detail := Trim(err.Message)
            if (detail == "") {
                detail := "No additional error details were provided."
            }
            result.errors.Push("Could not run ImageMagick for " sourcePath ": " detail)
            return
        }

        if !FileExist(outputPath) {
            result.failed += 1
            result.errors.Push("ImageMagick completed without creating output for " sourcePath ": " outputPath)
            return
        }

        try {
            if (FileGetSize(outputPath) <= 0) {
                this._DeleteOutput(outputPath)
                result.failed += 1
                result.errors.Push("ImageMagick created an empty output for " sourcePath ": " outputPath)
                return
            }
        } catch as err {
            this._DeleteOutput(outputPath)
            result.failed += 1
            detail := Trim(err.Message)
            if (detail == "") {
                detail := "No additional error details were provided."
            }
            result.errors.Push("Could not verify output for " sourcePath ": " detail)
            return
        }

        result.succeeded += 1
        result.outputs.Push(outputPath)
    }

    static _QuoteArgument(value) {
        return Chr(34) value Chr(34)
    }

    static _UniqueOutputPath(directory, baseName, extension) {
        outputPath := directory "\" baseName "." extension
        suffix := 2
        while FileExist(outputPath) {
            outputPath := directory "\" baseName "_" suffix "." extension
            suffix += 1
        }
        return outputPath
    }

    static _DeleteOutput(outputPath) {
        if FileExist(outputPath) {
            try FileDelete(outputPath)
            catch as err {
                OutputDebug("Could not remove incomplete image output " outputPath ": " err.Message)
            }
        }
    }

    static _IsSupportedOperation(operation) {
        return operation == "compress" || operation == "merge" || operation == "merge_horizontal"
            || operation == "merge_grid" || operation == "convert"
    }

    ; Turns a typed or pasted output name into a bare file name. Quotes,
    ; separators and reserved characters are removed, a trailing supported
    ; extension is dropped so the caller controls the format, and an
    ; unusable result becomes an empty string (the default name is used).
    static SanitizeOutputName(value) {
        if !(value is String)
            return ""

        name := Trim(value)
        if (StrLen(name) >= 2 && SubStr(name, 1, 1) == Chr(34) && SubStr(name, -1) == Chr(34))
            name := Trim(SubStr(name, 2, StrLen(name) - 2))
        name := Trim(RegExReplace(name, "[\\/:*?" Chr(34) "<>|]", ""))

        lowerName := StrLower(name)
        for format in this.SupportedFormats {
            extension := "." format
            if (StrLen(lowerName) > StrLen(extension) && SubStr(lowerName, -StrLen(extension)) == extension) {
                name := SubStr(name, 1, StrLen(name) - StrLen(extension))
                break
            }
        }
        return Trim(name)
    }

    ; Accepts #RRGGBB or #RRGGBBAA and returns the uppercase form. An empty
    ; value means the opaque white default; anything else fails loudly.
    static NormalizeBackground(value) {
        text := Trim(String(value))
        if (text == "")
            return "#FFFFFF"
        if !RegExMatch(text, "^#[0-9A-Fa-f]{6}([0-9A-Fa-f]{2})?$")
            throw ValueError("Merge background must be #RRGGBB or #RRGGBBAA.")
        return StrUpper(text)
    }

    ; Returns how many images land in each grid row, left to right. Rows are
    ; filled to the column count and the last row keeps the remainder.
    static GridRowSizes(count, columns) {
        if !IsNumber(count) || !IsNumber(columns)
            throw ValueError("Grid row sizing requires numeric arguments.")

        count := Round(count)
        columns := Round(columns)
        if (count < 0 || columns < 1)
            throw ValueError("Grid row sizing requires a non-negative count and at least one column.")

        sizes := []
        remaining := count
        while (remaining > 0) {
            take := Min(remaining, columns)
            sizes.Push(take)
            remaining -= take
        }
        return sizes
    }

    static _IsSupportedFormat(outputFormat) {
        for format in this.SupportedFormats {
            if (outputFormat == format) {
                return true
            }
        }
        return false
    }

    static _Fail(result, message) {
        result.failed := Max(1, result.failed)
        result.errors.Push(message)
        return result
    }
}
