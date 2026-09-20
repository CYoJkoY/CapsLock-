#Requires AutoHotkey v2.0

class SecureStorage {
    static Save(path, text) {
        text := String(text)
        bytes := StrPut(text, "UTF-8")
        data := Buffer(Max(bytes, 1), 0)
        StrPut(text, data, "UTF-8")

        inputBlob := Buffer(4 + A_PtrSize, 0)
        outputBlob := Buffer(4 + A_PtrSize, 0)

        NumPut("UInt", bytes - 1, inputBlob, 0)
        NumPut("Ptr", data.Ptr, inputBlob, 4)

        ok := DllCall(
            "Crypt32\CryptProtectData",
            "Ptr", inputBlob.Ptr,
            "Ptr", 0,
            "Ptr", 0,
            "Ptr", 0,
            "Ptr", 0,
            "UInt", 0,
            "Ptr", outputBlob.Ptr,
            "Int"
        )

        if !ok
            throw OSError()

        size := NumGet(outputBlob, 0, "UInt")
        ptr := NumGet(outputBlob, 4, "Ptr")

        encrypted := Buffer(size, 0)
        DllCall(
            "Kernel32\RtlMoveMemory",
            "Ptr", encrypted.Ptr,
            "Ptr", ptr,
            "Ptr", size
        )
        DllCall("Kernel32\LocalFree", "Ptr", ptr)

        dir := SubStr(path, 1, InStr(path, "\", , -1))
        if dir != "" && !DirExist(dir)
            DirCreate(dir)

        file := FileOpen(path, "w", "RAW")
        if !IsObject(file)
            throw Error("Could not open secure storage file.")

        try {
            file.RawWrite(encrypted, encrypted.Size)
            file.Close()
        } catch {
            try file.Close()
            throw
        }

        return true
    }

    static Load(path) {
        if !FileExist(path)
            return ""

        file := FileOpen(path, "r", "RAW")
        if !IsObject(file)
            return ""

        try {
            size := file.Length
            encrypted := Buffer(size, 0)
            file.RawRead(encrypted, size)
            file.Close()
        } catch {
            try file.Close()
            return ""
        }

        inputBlob := Buffer(4 + A_PtrSize, 0)
        outputBlob := Buffer(4 + A_PtrSize, 0)

        NumPut("UInt", size, inputBlob, 0)
        NumPut("Ptr", encrypted.Ptr, inputBlob, 4)

        ok := DllCall(
            "Crypt32\CryptUnprotectData",
            "Ptr", inputBlob.Ptr,
            "Ptr", 0,
            "Ptr", 0,
            "Ptr", 0,
            "Ptr", 0,
            "UInt", 0,
            "Ptr", outputBlob.Ptr,
            "Int"
        )

        if !ok
            return ""

        plainSize := NumGet(outputBlob, 0, "UInt")
        plainPtr := NumGet(outputBlob, 4, "Ptr")
        text := StrGet(plainPtr, plainSize, "UTF-8")

        DllCall("Kernel32\LocalFree", "Ptr", plainPtr)
        return text
    }

    static Delete(path) {
        if FileExist(path)
            try FileDelete(path)
    }
}
