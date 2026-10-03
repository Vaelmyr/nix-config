{ pkgs, ... }:

with pkgs; [
    # General-purpose fonts
    noto-fonts

    # Chinese / Japanese / Korean
    noto-fonts-cjk-sans
    noto-fonts-cjk-serif

    # Emoji
    noto-fonts-color-emoji

    # Icons
    font-awesome

    # Terminal/Development
    nerd-fonts.monaspace
]
