{
    version = "4.8-beta1";
    hash = "sha256-HpitMc1j036tTMfmTBJpzbeBOtk4ctvE+OQDFZ+5ujc=";
    rev = "4d10419cacd6d3009976e8f9fd3abd970fd58018";
    default = {
        exportTemplatesHash = "sha256-dLxec5bsGoEQcISdppMcyZsBsIYaZZwiuX6K3s+W1xo=";
    };
    mono = {
        exportTemplatesHash = "sha256-MozbozdcO89zLpyJXyNfs8u50PfChWOQPtW5ntwjPrY=";
        nugetDeps = ./deps.json;
    };
}
