{ pkgs, lib, ... }:

let
  augmentGrammar = grammar:
    pkgs.runCommandLocal "${grammar.pname}-augmented" {} ''
      mkdir $out
      ln -s ${grammar}/queries $out/queries
      mkdir $out/src
      head -n 3 ${grammar.src}/src/grammar.json > $out/src/grammar.json
      touch $out/src/parser.c
      ln -s ${grammar.src}/tree-sitter.json $out/tree-sitter.json
    '';

  prebuiltGrammars = pkgs.vimPlugins.nvim-treesitter.allGrammars;

  everything = builtins.map (grammar:
    let
      language = lib.pipe grammar [ lib.getName (lib.removeSuffix "-grammar") (lib.removePrefix "tree-sitter-") (lib.replaceStrings [ "-" ] [ "_" ]) ];
    in
    {
      inherit language;
      so = "${grammar}/parser";
      augmented = augmentGrammar grammar;
    }
  ) prebuiltGrammars;

  sharedObjects = pkgs.linkFarm "parsers" (
    builtins.map (el:
      let
        extension = if pkgs.stdenv.isDarwin then "dylib" else "so";
      in
      {
        name = "${el.language}.${extension}";
        path = el.so;
      }
    ) everything
  );

  grammarDirectories = pkgs.linkFarm "grammars" (
    builtins.map (el:
      {
        name = "tree-sitter-${el.language}";
        path = el.augmented;
      }
    )
  );

  treesitterConfig = {
    parser-directories = [
      grammarDirectories
    ];
    # theme stuff
    theme = {
      "property.builtin" = {
        color = 124;
        bold = true;
      };
      punctuation = 239;
      variable = 252;
      keyword = 56;
      embedded = null;
      comment = {
        color = 245;
        italic = true;
      };
      number = {
        color = 94;
        bold = true;
      };
      module = 136;
      "punctuation.delimiter" = 239;
      type = 23;
      constant = 94;
      attribute = {
        color = 124;
        italic = true;
      };
      "punctuation.bracket" = 239;
      string = 28;
      tag = 18;
      property = 124;
      "type.builtin" = {
        bold = true;
        color = 23;
      };
      "string.special" = 30;
      operator = {
        color = 239;
        bold = true;
      };
      "variable.parameter" = {
        color = 252;
        underline = true;
      };
      constructor = 136;
      "function.builtin" = {
        bold = true;
        color = 26;
      };
      "punctuation.special" = 239;
      "constant.builtin" = {
        "color" = 94;
        "bold" = true;
      };
      function = 26;
      "variable.builtin" = {
        "color" = 252;
        "bold" = true;
      };
    };
  };

  treesitterConfigPath = pkgs.writeText "config.json" (builtins.toJSON treesitterConfig);

  wrappedTreeSitter = pkgs.runCommandLocal "tree-sitter"
    {
      nativeBuildInputs = [ pkgs.makeBinaryWrapper ];
    }
    ''
      mkdir -p $out/bin
      makeWrapper "${lib.getExe pkgs.tree-sitter}" "$out/bin/tree-sitter" --add-flags "--config-path ${treesitterConfigPath}" --set-default TREE_SITTER_LIBDIR "${sharedObjects}"
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
