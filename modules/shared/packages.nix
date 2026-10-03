{ pkgs, ... }:

with pkgs; [
    # A

    # B
    bitwarden-desktop
    btop

    # C
    codex
    coreutils
    curl

    # D
    direnv

    # E
    # F
    firefox

    # G
    gh
    git
    google-cloud-sdk
    google-cloud-sql-proxy

    # H
    # I

    # J
    jq

    # K
    killall

    # L
    # M
    # N
    (if pkgs.stdenv.hostPlatform.isDarwin
        then notion-app
        else notion-electron
    )

    # O
    obsidian
    openssh

    # P
    # Q

    # R

    # S
    slack
    spotify

    # T
    tableplus
    telegram-desktop

    # U
    unrar
    unzip

    # V
    vesktop
    (if pkgs.stdenv.hostPlatform.isDarwin
        then vlc-bin
        else vlc
    )
    vscode

    # W
    wget

    # X
    # Y

    #Z
    zip
]
