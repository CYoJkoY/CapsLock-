#Requires AutoHotkey v2.0

FormatBytes(bytes) {
    if (bytes < 1024) {
        return bytes " B"
    } else if (bytes < 1048576) {
        return Round(bytes / 1024, 1) " KB"
    } else if (bytes < 1073741824) {
        return Round(bytes / 1048576, 1) " MB"
    } else if (bytes < 1099511627776) {
        return Round(bytes / 1073741824, 1) " GB"
    } else {
        return Round(bytes / 1099511627776, 1) " TB"
    }
}

Clamp(val, minVal, maxVal) {
    if (val < minVal) {
        return minVal
    } else if (val > maxVal) {
        return maxVal
    } else {
        return val
    }
}
