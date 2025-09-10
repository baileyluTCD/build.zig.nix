{ inputs, flake, ... }:
let
  inherit (inputs.nixpkgs) lib;

  eachSystem = lib.genAttrs (import inputs.systems);
in
eachSystem (
  system:
  let
    pkgs = inputs.nixpkgs.legacyPackages.${system};
  in
  {
    treefmt = inputs.treefmt-nix.lib.evalModule pkgs (import ./treefmtConfig.nix);
  }
)
// {
  version =
    let
      text = builtins.readFile (flake + "/build.zig.zon");
      lines = lib.splitString "\n" text;
      matchVersion = line: builtins.match ''^.*\.version = "(.*)".*$'' line;
      lineMatches = builtins.filter (m: m != null) (map matchVersion lines);
      matches = lib.flatten lineMatches;
    in
    assert lib.assertMsg (
      matches != null
    ) "No match could be found for build.zig.zon version field. Make sure '.version' is set";
    builtins.head matches;
}
