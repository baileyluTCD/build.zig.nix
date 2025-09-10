{
  pkgs,
  ...
}:
let
  inherit (pkgs) stdenvNoCC lib;
  inherit (lib) fileset;

  allowedSuffixes = [
    "zig"
    "zon"
  ];
in
stdenvNoCC.mkDerivation {
  name = "passes-zlint";

  src = fileset.toSource {
    root = ../..;
    fileset = fileset.fileFilter (
      file: builtins.any (suffix: lib.hasSuffix suffix file.name) allowedSuffixes
    ) ../..;
  };

  checkPhase = ''
    "${pkgs.zig-zlint}/bin/zlint" --deny-warnings
  '';

  installPhase = ''
    mkdir -p "$out"
  '';

  doCheck = true;
  dontBuild = true;
}
