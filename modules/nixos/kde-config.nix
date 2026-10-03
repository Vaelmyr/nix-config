{
    programs.plasma = {
        enable = true;

        shortcuts = {
            "kmix"."mic_mute" = [
                "Microphone Mute"
                "Meta+Volume Mute"
                "Shift+PgDown"
            ];
        };

        krunner.shortcuts.launch = "Alt+Space";

        configFile = {
            # Global settings
            "kdeglobals"."General"."ColorScheme" = "BreezeDark";

            # File dialog settings
            "kdeglobals"."KFileDialog Settings"."Breadcrumb Navigation" = true;
            "kdeglobals"."KFileDialog Settings"."Show Inline Previews" = true;
            "kdeglobals"."KFileDialog Settings"."Show Speedbar" = true;
            "kdeglobals"."KFileDialog Settings"."Sort directories first" = true;
            "kdeglobals"."KFileDialog Settings"."View Style" = "DetailTree";

            # Locale settings
            "plasma-localerc"."Formats"."LANG" = "en_US.UTF-8";
        };
    };
}
