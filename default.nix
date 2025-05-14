{ pkgs, lib, ... }:

let
  prebuiltGrammars = pkgs.vimPlugins.nvim-treesitter.allGrammars;

  everything = builtins.map (grammar:
    let
      language = lib.pipe grammar [ lib.getName (lib.removeSuffix "-grammar") (lib.removePrefix "tree-sitter-") (lib.replaceStrings [ "-" ] [ "_" ]) ];
    in
    {
      inherit language grammar;
    }
  ) prebuiltGrammars;

  sharedObjects = pkgs.linkFarm "parsers" (
    builtins.map (el:
      let
        extension = if pkgs.stdenv.isDarwin then "dylib" else "so";
      in
      {
        name = "${el.language}.${extension}";
        path = "${el.grammar}/parser";
      }
    ) everything
  );

  grammarDirectories = pkgs.linkFarm "grammars" (
    builtins.map (el:
      {
        name = "tree-sitter-${el.language}";
        path = el.grammar;
      }
    ) everything
  );

  treesitterConfig = {
    parser-directories = [
      grammarDirectories
    ];
    # theme stuff
    theme = builtins.fromJSON (builtins.readFile ./catppuccin-latte.json);
  };

  treesitterConfigPath = pkgs.writeText "config.json" (builtins.toJSON treesitterConfig);

  wrappedTreeSitter = pkgs.runCommandLocal "tree-sitter"
    {
      nativeBuildInputs = [ pkgs.makeBinaryWrapper ];
    }
    ''
      mkdir -p $out/bin
      # TODO: we should just write our own wrapper
      makeWrapper "${lib.getExe pkgs.tree-sitter}" "$out/bin/tree-sitter" --append-flags "--config-path ${treesitterConfigPath}" --set-default TREE_SITTER_LIBDIR "${sharedObjects}"
    '';

  highlighter = pkgs.symlinkJoin {
    name = "tree-sitter";
    # pkgs.symlinkJoin prefers the first
    paths = [
      wrappedTreeSitter
      pkgs.tree-sitter
    ];
  };

in

  highlighter
