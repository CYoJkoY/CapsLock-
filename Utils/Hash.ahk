#Requires AutoHotkey v2.0

Sha256(text) {
    text := String(text)
    dataSize := StrPut(text, "UTF-8") - 1
    data := Buffer(Max(dataSize, 1), 0)

    if dataSize > 0
        StrPut(text, data, "UTF-8")

    hAlg := 0
    hHash := 0
    objLength := 0
    cbResult := 0

    try {
        status := DllCall(
            "bcrypt\BCryptOpenAlgorithmProvider",
            "Ptr*", &hAlg,
            "WStr", "SHA256",
            "Ptr", 0,
            "UInt", 0,
            "UInt"
        )
        if status != 0
            throw Error("BCryptOpenAlgorithmProvider failed: 0x" Format("{:08X}", status))

        status := DllCall(
            "bcrypt\BCryptGetProperty",
            "Ptr", hAlg,
            "WStr", "ObjectLength",
            "UInt*", &objLength,
            "UInt", 4,
            "UInt*", &cbResult,
            "UInt"
        )
        if status != 0
            throw Error("BCryptGetProperty failed: 0x" Format("{:08X}", status))

        hashObject := Buffer(objLength, 0)

        status := DllCall(
            "bcrypt\BCryptCreateHash",
            "Ptr", hAlg,
            "Ptr*", &hHash,
            "Ptr", hashObject.Ptr,
            "UInt", hashObject.Size,
            "Ptr", 0,
            "UInt", 0,
            "UInt", 0,
            "UInt"
        )
        if status != 0
            throw Error("BCryptCreateHash failed: 0x" Format("{:08X}", status))

        if dataSize > 0 {
            status := DllCall(
                "bcrypt\BCryptHashData",
                "Ptr", hHash,
                "Ptr", data.Ptr,
                "UInt", dataSize,
                "UInt", 0,
                "UInt"
            )
            if status != 0
                throw Error("BCryptHashData failed: 0x" Format("{:08X}", status))
        }

        digest := Buffer(32, 0)
        status := DllCall(
            "bcrypt\BCryptFinishHash",
            "Ptr", hHash,
            "Ptr", digest.Ptr,
            "UInt", digest.Size,
            "UInt", 0,
            "UInt"
        )
        if status != 0
            throw Error("BCryptFinishHash failed: 0x" Format("{:08X}", status))

        result := ""
        Loop digest.Size
            result .= Format("{:02x}", NumGet(digest, A_Index - 1, "UChar"))

        return result
    } finally {
        if hHash
            DllCall("bcrypt\BCryptDestroyHash", "Ptr", hHash)
        if hAlg
            DllCall("bcrypt\BCryptCloseAlgorithmProvider", "Ptr", hAlg, "UInt", 0)
    }
}


Sha256Bytes(text) {
    text := String(text)
    dataSize := StrPut(text, "UTF-8") - 1
    data := Buffer(Max(dataSize, 1), 0)

    if dataSize > 0
        StrPut(text, data, "UTF-8")

    hAlg := 0
    hHash := 0
    objLength := 0
    cbResult := 0

    try {
        status := DllCall(
            "bcrypt\BCryptOpenAlgorithmProvider",
            "Ptr*", &hAlg,
            "WStr", "SHA256",
            "Ptr", 0,
            "UInt", 0,
            "UInt"
        )
        if status != 0
            throw Error("BCryptOpenAlgorithmProvider failed.")

        status := DllCall(
            "bcrypt\BCryptGetProperty",
            "Ptr", hAlg,
            "WStr", "ObjectLength",
            "UInt*", &objLength,
            "UInt", 4,
            "UInt*", &cbResult,
            "UInt"
        )
        if status != 0
            throw Error("BCryptGetProperty failed.")

        hashObject := Buffer(objLength, 0)

        status := DllCall(
            "bcrypt\BCryptCreateHash",
            "Ptr", hAlg,
            "Ptr*", &hHash,
            "Ptr", hashObject.Ptr,
            "UInt", hashObject.Size,
            "Ptr", 0,
            "UInt", 0,
            "UInt", 0,
            "UInt"
        )
        if status != 0
            throw Error("BCryptCreateHash failed.")

        if dataSize > 0 {
            status := DllCall(
                "bcrypt\BCryptHashData",
                "Ptr", hHash,
                "Ptr", data.Ptr,
                "UInt", dataSize,
                "UInt", 0,
                "UInt"
            )
            if status != 0
                throw Error("BCryptHashData failed.")
        }

        digest := Buffer(32, 0)
        status := DllCall(
            "bcrypt\BCryptFinishHash",
            "Ptr", hHash,
            "Ptr", digest.Ptr,
            "UInt", digest.Size,
            "UInt", 0,
            "UInt"
        )
        if status != 0
            throw Error("BCryptFinishHash failed.")

        return digest
    } finally {
        if hHash
            DllCall("bcrypt\BCryptDestroyHash", "Ptr", hHash)
        if hAlg
            DllCall("bcrypt\BCryptCloseAlgorithmProvider", "Ptr", hAlg, "UInt", 0)
    }
}
