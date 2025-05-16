{
  description = "tree-sitter highlight with Nix-built grammars";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs";
    tree-sitter-bencode = {
      url = "github:Samasaur1/tree-sitter-bencode";
      flake = false;
    };
  };

  outputs = { self, nixpkgs, tree-sitter-bencode, ... }:
    let
      allSystems = nixpkgs.lib.systems.flakeExposed;
      forAllSystems = nixpkgs.lib.genAttrs allSystems;
      define = f: forAllSystems (system:
        let
          pkgs = import nixpkgs {
            inherit system;
            config = {
            };
            overlays = [
              (import ./overlay.nix)
            ];
          };
        in
          f pkgs
      );
    in {
      packages = define (pkgs: {
        default = pkgs.callPackage ./. {
          tree-sitter-bencode-src = tree-sitter-bencode;
        };
      });
    };
}
