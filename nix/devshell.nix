{ pkgs, ... }:
pkgs.mkShellNoCC rec {
  packages = with pkgs; [
    zig_0_15
    zig-zlint

    nixfmt-rfc-style
    statix
    deadnix
  ];
}
