#Requires AutoHotkey v2.0

RandomBytes(size) {
    size := Integer(size)
    if size <= 0
        return Buffer(1, 0)

    mybuffer := Buffer(size, 0)
    status := DllCall(
        "bcrypt\BCryptGenRandom",
        "Ptr", 0,
        "Ptr", mybuffer.Ptr,
        "UInt", mybuffer.Size,
        "UInt", 0x00000002,
        "UInt"
    )

    if status != 0
        throw Error("BCryptGenRandom failed: 0x" Format("{:08X}", status))

    return mybuffer
}
