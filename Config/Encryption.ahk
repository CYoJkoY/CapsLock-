#Requires AutoHotkey v2.0

class Encryption {
    static KEY := 0x5A

    static CryptBuffer(buf) {
        key := this.KEY
        ptr := buf.Ptr
        size := buf.Size
        loop size // 4 {
            offset := (A_Index - 1) * 4
            NumPut("UInt", NumGet(ptr + offset, "UInt") ^ (key * 0x01010101), ptr + offset)
        }
        remOffset := size - Mod(size, 4)
        loop Mod(size, 4) {
            idx := remOffset + A_Index - 1
            NumPut("UChar", NumGet(ptr + idx, "UChar") ^ key, ptr + idx)
        }
        return buf
    }

    static CryptStream(buf, offset := 0) {
        ptr := buf.Ptr
        loop (buf.Size - offset) {
            i := offset + A_Index - 1
            NumPut("UChar", NumGet(ptr + i, "UChar") ^ (this.KEY + Mod(i * 13, 251)), ptr + i)
        }
        return buf
    }
}
