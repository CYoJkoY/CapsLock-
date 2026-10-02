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

        ; Write to a temp file first, then atomically replace: 
        ; a crash midway won't leave behind a half-written, corrupted credentials.dat
        ; The explicit CP0 keeps RawWrite byte-exact (no BOM, no translation) even
        ; if the global FileEncoding were ever changed; v2's FileOpen has no
        ; "RAW" encoding and passing one would throw.
        tmpPath := path ".tmp"
        myfile := FileOpen(tmpPath, "w", "CP0")
        if !IsObject(myfile)
            throw Error("Could not open secure storage file.")

        try {
            myfile.RawWrite(encrypted, encrypted.Size)
            myfile.Close()
        } catch {
            try myfile.Close()
            try FileDelete(tmpPath)
            throw
        }

        try
            FileMove(tmpPath, path, true)
        catch as err {
            try FileDelete(tmpPath)
            throw err
        }

        return true
    }

    static Load(path) {
        if !FileExist(path)
            return ""

        ; See Save: CP0 + RawRead is the byte-exact read; Seek(0) undoes any
        ; leading-BOM skip so the whole encrypted blob is returned.
        myfile := FileOpen(path, "r", "CP0")
        if !IsObject(myfile)
            return ""

        try {
            size := myfile.Length
            encrypted := Buffer(size, 0)
            myfile.Seek(0)
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
