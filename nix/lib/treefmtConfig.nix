_: {
  projectRootFile = "flake.nix";

  programs = {
    deadnix.enable = true;
    nixfmt.enable = true;
    shfmt.enable = true;
    zig.enable = true;
    mdformat.enable = true;
  };
}
