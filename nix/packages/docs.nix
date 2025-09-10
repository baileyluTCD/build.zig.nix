{
  flake,
  pkgs,
  ...
}:
let
  inherit (pkgs) stdenvNoCC;
in
stdenvNoCC.mkDerivation {
  pname = "docs";
  inherit (flake.lib) version;

  src = flake;

  nativeBuildInputs = with pkgs; [
    zig_0_15.hook
    makeWrapper
  ];

  buildPhase = ''
    zig build docs
  '';

  installPhase = ''
    mkdir -p $out/{bin,docs}

    cp -r "./zig-out/docs/." "$out/docs"

    makeWrapper ${pkgs.caddy}/bin/caddy $out/bin/weld-docs \
      --add-flags "file-server" \
      --add-flags "--root $out/docs" \
      --add-flags "--listen :8000"
  '';
}
