#Requires AutoHotkey v2.0

PlayResourceSound( resourceName ) {
    hModule := DllCall( "GetModuleHandle", "Ptr", 0, "Ptr" )
    hResInfo := DllCall( "FindResource", "Ptr", hModule, "Str", resourceName, "UInt", 10, "Ptr" )
    if !hResInfo {
        return
    }
    resSize := DllCall( "SizeofResource", "Ptr", hModule, "Ptr", hResInfo, "UInt" )
    hResData := DllCall( "LoadResource", "Ptr", hModule, "Ptr", hResInfo, "Ptr" )
    pResource := DllCall( "LockResource", "Ptr", hResData, "Ptr" )
    if !pResource {
        return
    }
    DllCall( "winmm\PlaySoundW", "Ptr", pResource, "Ptr", 0, "UInt", 0x5 )
}
