#Requires AutoHotkey v2.0

class SecureStorage {
    static Save(path, text) {
        text := String(text)
        bytes := StrPut(text, "UTF-8")
        data := Buffer(Max(bytes, 1), 0)
        StrPut(text, data, "UTF-8")

        inputBlob := Buffer(8 + A_PtrSize, 0)
        outputBlob := Buffer(8 + A_PtrSize, 0)
        ptrOffset := A_PtrSize == 8 ? 8 : 4

        NumPut("UInt", bytes - 1, inputBlob, 0)
        NumPut("Ptr", data.Ptr, inputBlob, ptrOffset)

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
        ptr := NumGet(outputBlob, ptrOffset, "Ptr")

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

        myfile := FileOpen(path, "w", "RAW")
        if !IsObject(myfile)
            throw Error("Could not open secure storage file.")

        try {
            myfile.RawWrite(encrypted, encrypted.Size)
            myfile.Close()
        } catch {
            try myfile.Close()
            throw
        }

        return true
    }

    static Load(path) {
        if !FileExist(path)
            return ""

        myfile := FileOpen(path, "r", "RAW")
        if !IsObject(myfile)
            return ""

        try {
            size := myfile.Length
            encrypted := Buffer(size, 0)
            myfile.RawRead(encrypted, size)
            myfile.Close()
        } catch {
            try myfile.Close()
            return ""
        }

        inputBlob := Buffer(8 + A_PtrSize, 0)
        outputBlob := Buffer(8 + A_PtrSize, 0)
        ptrOffset := A_PtrSize == 8 ? 8 : 4

        NumPut("UInt", size, inputBlob, 0)
        NumPut("Ptr", encrypted.Ptr, inputBlob, ptrOffset)

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
        plainPtr := NumGet(outputBlob, ptrOffset, "Ptr")
        text := StrGet(plainPtr, plainSize, "UTF-8")

        DllCall("Kernel32\LocalFree", "Ptr", plainPtr)
        return text
    }

    static Delete(path) {
        if FileExist(path)
            try FileDelete(path)
    }
}
