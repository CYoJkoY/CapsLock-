#Requires AutoHotkey v2.0

ShowPreviewGui( text ) {
    myGui := Gui( "+AlwaysOnTop +Resize", Lang( "GUI_PREVIEW_TITLE" ) )
    myGui.SetFont( "s10", "Microsoft YaHei" )
    myEdit := myGui.Add( "Edit", "ReadOnly VScroll Wrap w600 h400", text )
    btn := myGui.Add( "Button", "Default w80", Lang( "GUI_PREVIEW_CLOSE" ) )
    btn.OnEvent( "Click", ( * ) => myGui.Destroy() )
    myGui.OnEvent( "Size", ( obj, minmax, w, h ) => (
        myEdit.Move( 10, 10, w - 20, h - 60 ),
        btn.Move( w - 100, h - 40 )
    ) )
    myGui.OnEvent( "Escape", ( * ) => myGui.Destroy() )
    myGui.Show()
}
