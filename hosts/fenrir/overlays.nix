[
    (final: prev: {
        # Pin official previews independently of nixpkgs' stable Godot.
        godotPreviewPackages = final.callPackage ../../pkgs/godot { };
        godot-preview = final.godotPreviewPackages.godot;
        godot-mono-preview = final.godotPreviewPackages.godot-mono;

        # TablePlus needs GIO's TLS backend for HTTPS license activation.
        tableplus = prev.tableplus.overrideAttrs (old: {
            buildInputs = (old.buildInputs or []) ++ [ final.glib-networking ];
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
