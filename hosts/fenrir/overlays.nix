[
    (final: prev: {
        a2tools-dps-meter = final.callPackage ../../pkgs/a2tools-dps-meter { };

        # Use upstream's binary build for compatibility with the Bambu network plugin.
        orca-slicer = final.callPackage ../../pkgs/orca-slicer { };

        fusion360 = final.callPackage ../../pkgs/fusion360 { };

        curseforge = final.callPackage ../../pkgs/curseforge { };

        # Pin the Mono preview independently of nixpkgs' stable Godot.
        godot-mono-preview = (final.callPackage ../../pkgs/godot { }).godot-mono;

        # The downloaded C# debugger loads ICU dynamically outside nix-ld's startup.
        vscode = prev.vscode.overrideAttrs (old: {
            postFixup = (old.postFixup or "") + ''
                wrapProgram $out/bin/code \
                    --prefix LD_LIBRARY_PATH : ${final.lib.makeLibraryPath [ final.icu ]}
            '';
        });

        # Patchelf 0.19.2 gives Cursor's Node helper overlapping LOAD segments,
        # making .dynamic read-only and crashing the loader when it writes DT_DEBUG.
        # https://github.com/NixOS/patchelf/releases/tag/0.19.3
        code-cursor = let
            cursorPatchelf = prev.patchelf.overrideAttrs {
                version = "0.19.3";
                src = final.fetchurl {
                    url = "https://github.com/NixOS/patchelf/releases/download/0.19.3/patchelf-0.19.3.tar.gz";
                    hash = "sha256-+sdqPAtzDo1T6h0QzWAVMi14yZAK+Rc28sylHVg3thI=";
                };
            };
        in prev.code-cursor.overrideAttrs (old: {
            nativeBuildInputs = [ cursorPatchelf ] ++ (old.nativeBuildInputs or []);
        });

        # TablePlus needs GIO's TLS backend for HTTPS license activation
        # and PostgreSQL client tools on PATH for database backups/restores.
        tableplus = prev.tableplus.overrideAttrs (old: {
            buildInputs = (old.buildInputs or []) ++ [ final.glib-networking ];
            preFixup = (old.preFixup or "") + ''
                gappsWrapperArgs+=(--prefix PATH : ${final.lib.makeBinPath [ final.postgresql_18 ]})
            '';
        });

        # ROCm SMI's default pci.ids paths are unavailable on NixOS.
        rocmPackages = prev.rocmPackages.overrideScope (rocmFinal: rocmPrev: {
            rocm-smi = rocmPrev.rocm-smi.overrideAttrs (old: {
                postPatch = (old.postPatch or "") + ''
                    substituteInPlace src/rocm_smi.cc \
                        --replace-fail /usr/share/misc/pci.ids ${final.hwdata}/share/hwdata/pci.ids
                '';
            });
        });

        # Enable AMD GPU monitoring in both system and Home Manager's btop.
        btop = prev.btop.override {
            rocmSupport = true;
            rocmPackages = final.rocmPackages;
        };
    })
]
