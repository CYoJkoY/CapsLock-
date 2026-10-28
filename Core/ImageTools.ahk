#Requires AutoHotkey v2.0

class ImageTools {
    static SupportedFormats := ["jpg", "jpeg", "png", "webp", "gif", "tif", "tiff", "bmp"]

    static Execute(paths, operation, outputFormat, quality, outputDirectory) {
        result := { succeeded: 0, failed: 0, outputs: [], errors: [] }

        if !(paths is Array) {
            return this._Fail(result, "Input paths must be an array.")
        }
        if (paths.Length == 0) {
            return this._Fail(result, "No input image paths were provided.")
        }
        if !(operation is String) || !this._IsSupportedOperation(operation) {
            return this._Fail(result, "Unsupported operation. Use compress, merge, or convert.")
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

        if (operation == "merge" && result.failed > 0) {
            return result
        }
        if (operation == "merge" && validPaths.Length < 2) {
            return this._Fail(result, "Select at least two valid images to combine.")
        }

        if (operation == "merge") {
            this._Merge(validPaths, exe, outputFormat, quality, outputDirectory, result)
            return result
        }

        for path in validPaths {
            this._ProcessOne(path, exe, operation, outputFormat, quality, outputDirectory, result)
        }
        return result
    }

    static _ProcessOne(path, exe, operation, outputFormat, quality, outputDirectory, result) {
        SplitPath(path, , , , &nameWithoutExtension)
        suffix := operation == "compress" ? "_compressed" : "_converted"
        if (StrLower(path) == StrLower(outputDirectory "\" nameWithoutExtension "." outputFormat))
            suffix := "_" operation
        outputPath := this._UniqueOutputPath(outputDirectory, nameWithoutExtension suffix, outputFormat)

        arguments := this._QuoteArgument(exe) " " this._QuoteArgument(path) " -strip -quality " quality " " this._QuoteArgument(outputPath)
        this._Run(arguments, outputPath, path, result)
    }

    static _Merge(paths, exe, outputFormat, quality, outputDirectory, result) {
        outputPath := this._UniqueOutputPath(outputDirectory, "merged_" FormatTime(, "yyyyMMdd_HHmmss"), outputFormat)

        arguments := this._QuoteArgument(exe)
        for path in paths {
            arguments .= " " this._QuoteArgument(path)
        }
        arguments .= " -append -strip -quality " quality " " this._QuoteArgument(outputPath)
        this._Run(arguments, outputPath, "merge", result)
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
        return operation == "compress" || operation == "merge" || operation == "convert"
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
