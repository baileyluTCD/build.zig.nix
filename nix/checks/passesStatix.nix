{
  pkgs,
  ...
}:
let
  inherit (pkgs) stdenvNoCC lib;
  inherit (lib) fileset;

  allowedSuffixes = [
    "nix"
  ];
in
stdenvNoCC.mkDerivation {
  name = "passes-statix";

  src = fileset.toSource {
    root = ../..;
    fileset = fileset.fileFilter (
      file: builtins.any (suffix: lib.hasSuffix suffix file.name) allowedSuffixes
    ) ../..;
  };

  checkPhase = ''
    "${pkgs.statix}/bin/statix" check
  '';

  installPhase = ''
    mkdir -p "$out"
  '';

  doCheck = true;
  dontBuild = true;
}
