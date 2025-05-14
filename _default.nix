{ pkgs, lib, ... }:

let
  buildGrammar = pkgs.tree-sitter.buildGrammar;
  buildGrammar' = buildGrammar.overrideAttrs {
    installPhase = ''
      runHook preInstall
      mkdir $out
      mv parser $out/
      if [[ -d queries ]]; then
        cp -r queries $out
      fi
      if [[ -e tree-sitter.json ]]; then
        cp tree-sitter.json $out
      fi
      if [[ -e src/grammar.json ]]; then
        mkdir -p $out/src
        head -n 3 src/grammar.json > $out/src/grammar.json
        # mv src/grammar.json $out/src/
      fi
      runHook postInstall
    '';
  };

  # treeSitterBuiltGrammars = pkgs.tree-sitter.builtGrammars;
  # nvimTreesitterBuiltGrammars = pkgs.vimPlugins.nvim-treesitter.builtGrammars;
  #
  # grammars = lib.attrValues

  prebuiltGrammars = pkgs.vimPlugins.nvim-treesitter.allGrammars;

  rebuiltGrammars = builtins.map (grammar:
    let
      language = lib.pipe grammar [ lib.getName (lib.removeSuffix "-grammar") (lib.removePrefix "tree-sitter-") (lib.replaceStrings [ "-" ] [ "_" ]) ];
      inherit (grammar) version src;
      originalConfigurePhase = grammar.configurePhase;
      generate = (builtins.match ".*tree-sitter generate.*" originalConfigurePhase) != null;
      location' = if generate then builtins.match "^cd (.*)\n.*\n" originalConfigurePhase else builtins.match "^cd (.*)\n" originalConfigurePhase;
      location = if location' == null then null else builtins.elemAt location' 0;
      rebuiltGrammar = buildGrammar' { inherit language version src location generate; };
    in
      rebuiltGrammar
  ) prebuiltGrammars;

  sharedObjects = pkgs.linkFarm "parsers" (
    map (
      drv:
      let
        name = lib.strings.getName drv;
      in
        {
        name =
          (lib.strings.replaceStrings [ "-" ] [ "_" ] (
            lib.strings.removePrefix "tree-sitter-" (lib.strings.removeSuffix "-grammar" name)
          ))
          + ".so";
        path = "${drv}/parser";
      }
    ) rebuiltGrammars # 
  );

in

  highlighter
