{
  flake,
  pkgs,
  ...
}:
let
  inherit (pkgs) stdenvNoCC;
in
stdenvNoCC.mkDerivation {
  pname = "passes-zig-build-test";
  inherit (flake.lib) version;

  src = flake;

  nativeBuildInputs = with pkgs; [
    zig_0_15.hook
  ];

  checkPhase = ''
    zig build test
  '';

  installPhase = ''
    mkdir -p "$out"
  '';

  doCheck = true;
  dontBuild = true;
}
