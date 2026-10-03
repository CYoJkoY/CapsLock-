#Requires AutoHotkey v2.0

class AppState {
    ; --- Core Data ---
    static History := []
    static MaxHistory := 10000
    static TargetWindow := 0

    ; --- Quick Phrase ---
    static QuickPhraseEnabled := true
    static QuickPhraseFile := A_ScriptDir "\configs\QuickPhrases.ini"
    static QuickPhraseContentDir := A_ScriptDir "\configs\QuickPhrases"
    static QuickPhraseGui := ""
    static QuickPhraseManagerGui := ""
    static QuickPhraseVariableGui := ""
    static QuickPhraseTransactionActive := false
    static QuickPhraseExternalTarget := ""

    ; --- Settings ---
    static PasteMode := 1
    static DeleteMode := 1
    static DeleteDelay := 10
    static CleanupInterval := 30
    static ThemeMode := "dark"

    ; --- Runtime State ---
    static LastManualClipboard := ""
    static IgnoreNextClipChange := false
    static FullHistoryGui := ""
    static SettingsGui := ""
    static MenuPosX := 0
    static MenuPosY := 0
    static ImageMagickExe := ""

    ; --- Shift Layer ---
    static ShiftLayerActive := false
    static ShiftLayerTimer := ""

    ; --- Language ---
    static CurrentLanguage := ""

    ; --- Paths ---
    static ConfigFile := A_ScriptDir "\configs\Config.ini"
    static HistoryFile := A_ScriptDir "\configs\ClipHistory.bin"
    static ENCRYPT_KEY := 0x5A
    static _init := DirExist(A_ScriptDir "\configs") ? "" : DirCreate(A_ScriptDir "\configs")

    ; --- UI Constants ---
    static MAX_VISIBLE_MENU := 12
    static MAX_FULL_HISTORY_DISPLAY := 50

    ; --- UI Theme (Google Chrome / Workspace Material Design) ---
    static THEME_BG := "0x202124"
    static THEME_SURFACE := "0x292A2D"
    static THEME_ELEVATED := "0x1F3760"
    static THEME_CONTROL_BG := "0x303134"
    static THEME_CONTROL_HOVER := "0x3C4043"
    static THEME_BORDER := "0x3C4043"

    static THEME_FG := "0xE8EAED"
    static THEME_FG_DIM := "0x9AA0A6"
    static THEME_FG_MUTED := "0x80868B"

    static THEME_ACCENT := "0x8AB4F8"
    static THEME_ACCENT_DARK := "0x1A73E8"
    static THEME_ACCENT_GLOW := "0xD2E3FC"

    static THEME_SUCCESS := "0x81C995"
    static THEME_WARNING := "0xFDD663"
    static THEME_DANGER := "0xD93025"

    ; Foreground used on accent-filled surfaces (primary / danger buttons).
    static THEME_ON_ACCENT := "0xFFFFFF"

    ; Google Brand 4-Color Accents
    static GOOGLE_BLUE := "0x4285F4"
    static GOOGLE_RED := "0xEA4335"
    static GOOGLE_YELLOW := "0xFBBC05"
    static GOOGLE_GREEN := "0x34A853"

    static THEME_FONT := "Segoe UI"
    static THEME_FONT_MONO := "Cascadia Code"
    static THEME_RADIUS := 12

    ; --- Theme Palettes ---
    ; The single source of truth for both themes. AppState.THEME_* above holds
    ; the values of the active theme; Theme.Apply() copies one of these
    ; palettes into those fields. Adding a theme means adding one entry here
    ; instead of touching individual windows.
    ;
    ; Colours are AHK RGB strings (0xRRGGBB). ThemeHelper converts them to
    ; GDI COLORREF (0xBBGGRR) when talking to the Win32 API.
    static THEME_PALETTES := Map(
        "dark", Map(
            ; Google Chrome / Workspace Dark palette:
            ; Deep #202124 canvas, #292A2D elevated cards, #1F3760 tonal selection
            ; pill, and signature #8AB4F8 / #1A73E8 Google Blue accents.
            "THEME_BG", "0x202124",
            "THEME_SURFACE", "0x292A2D",
            "THEME_ELEVATED", "0x1F3760",
            "THEME_CONTROL_BG", "0x303134",
            "THEME_CONTROL_HOVER", "0x3C4043",
            "THEME_BORDER", "0x3C4043",
            "THEME_FG", "0xE8EAED",
            "THEME_FG_DIM", "0x9AA0A6",
            "THEME_FG_MUTED", "0x80868B",
            "THEME_ACCENT", "0x8AB4F8",
            "THEME_ACCENT_DARK", "0x1A73E8",
            "THEME_ACCENT_GLOW", "0xD2E3FC",
            "THEME_SUCCESS", "0x81C995",
            "THEME_WARNING", "0xFDD663",
            "THEME_DANGER", "0xD93025",
            "THEME_ON_ACCENT", "0xFFFFFF"
        ),
        "light", Map(
            ; Google Chrome / Workspace Light palette:
            ; Crisp #F8F9FA neutral canvas, #FFFFFF elevated cards, #E8F0FE
            ; tonal blue selection pill, and #1A73E8 Google Blue accents.
            "THEME_BG", "0xF8F9FA",
            "THEME_SURFACE", "0xFFFFFF",
            "THEME_ELEVATED", "0xE8F0FE",
            "THEME_CONTROL_BG", "0xF1F3F4",
            "THEME_CONTROL_HOVER", "0xE8EAED",
            "THEME_BORDER", "0xDADCE0",
            "THEME_FG", "0x202124",
            "THEME_FG_DIM", "0x5F6368",
            "THEME_FG_MUTED", "0x80868B",
            "THEME_ACCENT", "0x1A73E8",
            "THEME_ACCENT_DARK", "0x1A73E8",
            "THEME_ACCENT_GLOW", "0x174EA6",
            "THEME_SUCCESS", "0x1E8E3E",
            "THEME_WARNING", "0xF9AB00",
            "THEME_DANGER", "0xD93025",
            "THEME_ON_ACCENT", "0xFFFFFF"
        )
    )

    ; --- File Types ---
    static TextFormats := [
        "txt", "log", "md", "rtf",
        "tex", "wri", "ini", "cfg",
        "json", "xml", "yaml", "yml",
        "toml", "properties", "env",
        "c", "cpp", "cxx", "h", "js",
        "ts", "html", "htm", "css", "php",
        "jsp", "asp", "apsx", "vue", "scss",
        "sass", "less", "py", "java", "go",
        "rs", "rb", "kt", "cs", "sql", "r",
        "lua", "vb", "bat", "cmd", "sh", "ps1",
        "gd", "gdshader", "tres", "tscn"
    ]

    static ImageFormats := [
        "png", "jpg", "jpeg", "bmp",
        "gif", "tiff", "tif", "webp",
        "ico", "heic"
    ]

    ; --- Paste heuristics ---
    static TextInputControls := [
        "Edit", "RichEdit", "RichEdit20A", "RichEdit20W", "RICHEDIT50W",
        "Scintilla", "TMemo", "TSyntaxMemo", "AkelEditA", "AkelEditW",
        "TJvRichEdit", "TEdit", "EditControl"
    ]

    ; --- Ignore / Auto Clean ---
    static IgnorePatterns := []
    static AutoCleanEnabled := false
    static MaxHistoryItems := 500

    ; --- Window Hole ---
    static WindowHoleDiameter := 360
    static WindowHoleShape := "circle"
    static WindowHoleActivation := "hold"
    static WindowHoleUpdateInterval := 30
    static WindowHoleFallbackToMinimize := true
    static WindowHoleAllowedExecutables := []
    static WindowHoleExcludedExecutables := []
    static WindowHoleAllowedClasses := []
    static WindowHoleExcludedClasses := []

    ; --- Window Switcher ---
    static WindowSwitcherShowIcons := true
    static WindowSwitcherIconSize := 24
    static WindowSwitcherDensity := "normal"
    static WindowSwitcherShowProcess := true
    static WindowSwitcherHighlightRow := true

    static WindowSwitcherIconSizes := [16, 20, 24, 32]
    static WindowSwitcherDensities := ["compact", "normal", "spacious"]

    ; --- Always-on-top indicator ---
    ; Persistent pin badge on every pinned window (CapsLock + T). Without it the
    ; pinned state is only visible for the lifetime of the OSD toast.
    static AlwaysOnTopIndicator := true

    ; --- Spotlight (CapsLock + O) ---
    static SpotlightRadius := 180          ; clear radius in px (40 - 900)
    static SpotlightSoftness := 60         ; feather width in px (0 - 250)
    static SpotlightDarkness := 55         ; dim opacity in % (5 - 95)
    static SpotlightShape := "circle"      ; circle | rounded | square
    static SpotlightActivation := "toggle" ; hold | toggle
    static SpotlightUpdateInterval := 16   ; cursor tracking period in ms

    static SpotlightShapes := ["circle", "rounded", "square"]
    static SpotlightActivations := ["hold", "toggle"]

    ; --- Dynamic Zoom (CapsLock + Z) ---
    static ZoomFactor := 3                 ; magnification factor (2 - 16)
    static ZoomActivation := "toggle"      ; hold | toggle
    static ZoomUpdateInterval := 16        ; cursor tracking period in ms

    static ZoomActivations := ["hold", "toggle"]

    ; --- Pandoc Settings ---
    static PandocExe := ""
    static PandocOutputFormat := "docx"

    ; --- Cloud Sync ---
    static CloudSyncEnabled := false
    static CloudSyncProvider := "gist"
    static CloudSyncTarget := ""
    static CloudSyncAutoEnabled := false
    static CloudSyncInterval := 30
    static CloudSyncEncryptionEnabled := false
    static CloudSyncDeviceName := ""
    static CloudSyncState := "disabled"
    static CloudSyncLastSuccess := ""
    static CloudSyncConflict := false
    static CloudSyncApplying := false
    static CloudSyncLocalDirty := false
    static CloudSyncLastError := ""

    static CloudSyncDir := A_ScriptDir "\configs\CloudSync"
    static CloudSyncStateFile := A_ScriptDir "\configs\CloudSync\state.ini"
    static CloudSyncBaseFile := A_ScriptDir "\configs\CloudSync\base.json"
    static CloudSyncCredentialFile := A_ScriptDir "\configs\CloudSync\credentials.dat"
    static CloudSyncBackupDir := A_ScriptDir "\configs\CloudSync\backups"
    static CloudSyncConflictDir := A_ScriptDir "\configs\CloudSync\conflicts"
    static CloudSyncStagingDir := A_ScriptDir "\configs\CloudSync\staging"

    ; --- Pandoc format lists ---
    static PandocInputFormats := [
        "asciidoc", "biblatex", "bibtex", "bits", "commonmark", "commonmark_x",
        "creole", "csljson", "csv", "djot", "docbook", "docx", "dokuwiki",
        "endnotexml", "epub", "fb2", "gfm", "haddock", "html", "ipynb", "jats",
        "jira", "json", "latex", "man", "markdown", "markdown_github",
        "markdown_mmd", "markdown_phpextra", "markdown_strict", "mdoc",
        "mediawiki", "muse", "native", "odt", "opml", "org", "pod", "pptx", "ris",
        "rst", "rtf", "t2t", "textile", "tikiwiki", "tsv", "twiki", "typst",
        "vimwiki", "xlsx", "xml"
    ]

    static PandocOutputFormats := [
        "ansi", "asciidoc", "asciidoc_legacy", "asciidoctor", "bbcode",
        "bbcode_fluxbb", "bbcode_hubzilla", "bbcode_phpbb", "bbcode_steam",
        "bbcode_xenforo", "beamer", "biblatex", "bibtex", "chunkedhtml",
        "commonmark", "commonmark_x", "context", "csljson", "djot", "docbook",
        "docbook4", "docbook5", "docx", "dokuwiki", "dzslides", "epub", "epub2",
        "epub3", "fb2", "gfm", "haddock", "html", "html4", "html5", "icml",
        "ipynb", "jats", "jats_archiving", "jats_articleauthoring",
        "jats_publishing", "jira", "json", "latex", "man", "markdown",
        "markdown_mmd", "markdown_phpextra", "markdown_strict", "markua", "mediawiki",
        "ms", "muse", "native", "odt", "opendocument", "opml", "org", "pdf", "plain",
        "pptx", "revealjs", "rst", "rtf", "s5", "slideous", "slidy", "t2t", "tei",
        "texinfo", "textile", "typst", "vimdoc", "xml", "xwiki", "zimwiki"
    ]
}
