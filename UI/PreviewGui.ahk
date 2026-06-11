#Requires AutoHotkey v2.0

ShowPreviewGui( text ) {
    PreviewGui := Gui( "+AlwaysOnTop +Resize", "Preview Content" )
    PreviewGui.SetFont( "s10", "Microsoft YaHei" )

    EditCtrl := PreviewGui.Add( "Edit", "ReadOnly VScroll Wrap w600 h400", text )
    BtnClose := PreviewGui.Add( "Button", "Default w80", "Close" )
    BtnClose.OnEvent( "Click", ( * ) => PreviewGui.Destroy() )

    PreviewGui.OnEvent( "Size", ( guiObj, windowMinMax, width, height ) => (
        EditCtrl.Move( 10, 10, width - 20, height - 60 ),
        BtnClose.Move( width - 100, height - 40 )
    ) )
    PreviewGui.OnEvent( "Escape", ( * ) => PreviewGui.Destroy() )
    PreviewGui.Show()
}
