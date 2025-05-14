final: prev:
let
  buildGrammar = prev.tree-sitter.buildGrammar;
  buildGrammar' = args: (buildGrammar args).overrideAttrs {
    installPhase = ''
      runHook preInstall
      mkdir $out
      mv parser $out/
      if [[ -d queries ]]; then
        cp -r queries $out
      fi
      mkdir -p $out/src
      if [[ -e src/grammar.json ]]; then
        head -n 3 src/grammar.json > $out/src/grammar.json
        # cp src/grammar.json $out/src/
      fi
      touch $out/src/parser.c
      if [[ -e tree-sitter.json ]]; then
        cp tree-sitter.json $out
      fi
      runHook postInstall
    '';
  };
in
{
  tree-sitter = prev.tree-sitter.overrideAttrs {
    passthru.buildGrammar = buildGrammar';
  };
}
