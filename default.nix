{ pkgs, lib, tree-sitter-bencode-src, ... }:

let
  tree-sitter-bencode = pkgs.tree-sitter.buildGrammar {
    language = "bencode";
    version = "0.1.0";
    src = tree-sitter-bencode-src;
    generate = true;
  };

  prebuiltGrammars = pkgs.vimPlugins.nvim-treesitter.allGrammars ++ [tree-sitter-bencode];

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

  theme = builtins.fromJSON (builtins.readFile ./catppuccin-latte.json);
  theme' = theme // {
    "parameter" = theme."variable.parameter" or null;
    "field" = theme."variable.member" or null;
    "namespace" = theme."module" or null;
    "float" = theme."number.float" or null;
    "symbol" = theme."string.special.symbol" or null;
    "string.regex" = theme."string.regexp" or null;

    "text" = theme."markup" or null;
    "text.strong" = theme."markup.strong" or null;
    "text.emphasis" = theme."markup.italic" or null;
    "text.underline" = theme."markup.underline" or null;
    "text.strike" = theme."markup.strikethrough" or null;
    "text.uri" = theme."markup.link.url" or null;
    "text.math" = theme."markup.math" or null;
    "text.environment" = theme."markup.environment" or null;
    "text.environment.name" = theme."markup.environment.name" or null;

    "text.title" = theme."markup.heading" or null;
    "text.literal" = theme."markup.raw" or null;
    "text.reference" = theme."markup.link" or null;

    "text.todo.checked" = theme."markup.list.checked" or null;
    "text.todo.unchecked" = theme."markup.list.unchecked" or null;

    "comment.note" = theme."comment.hint" or null;

    # @text.todo is now for todo comments, not todo notes like in markdown
    "text.todo" = theme."comment.todo" or null;
    "text.warning" = theme."comment.warning" or null;
    "text.note" = theme."comment.note" or null;
    "text.danger" = theme."comment.error" or null;

    # # @text.uri is now
    # # > @markup.link.url in markup links
    # # > @string.special.url outside of markup
    # "text.uri" = theme."markup.link.uri" or null;

    "method" = theme."function.method" or null;
    "method.call" = theme."function.method.call" or null;

    "text.diff.add" = theme."diff.plus" or null;
    "text.diff.delete" = theme."diff.minus" or null;

    "type.qualifier" = theme."keyword.modifier" or null;
    "keyword.storage" = theme."keyword.modifier" or null;
    "define" = theme."keyword.directive.define" or null;
    "preproc" = theme."keyword.directive" or null;
    "storageclass" = theme."keyword.storage" or null;
    "conditional" = theme."keyword.conditional" or null;
    "exception" = theme."keyword.exception" or null;
    "include" = theme."keyword.import" or null;
    "repeat" = theme."keyword.repeat" or null;

    "symbol.ruby" = theme."string.special.symbol.ruby" or null;

    "variable.member.yaml" = theme."field.yaml" or null;

    "text.title.1.markdown" = theme."markup.heading.1.markdown" or null;
    "text.title.2.markdown" = theme."markup.heading.2.markdown" or null;
    "text.title.3.markdown" = theme."markup.heading.3.markdown" or null;
    "text.title.4.markdown" = theme."markup.heading.4.markdown" or null;
    "text.title.5.markdown" = theme."markup.heading.5.markdown" or null;
    "text.title.6.markdown" = theme."markup.heading.6.markdown" or null;

    "method.php" = theme."function.method.php" or null;
    "method.call.php" = theme."function.method.call.php" or null;
  };

  treesitterConfig = {
    parser-directories = [
      grammarDirectories
    ];
    # theme stuff
    theme = theme';
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
