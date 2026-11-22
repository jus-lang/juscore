{
  description = "JusCore: implementação de referência (front-end, interpretador e, no futuro, backend Michelson)";

  inputs = {
    # Ramo estável mais recente do nixpkgs no momento da criação do repositório.
    # Conferir o nome do ramo em https://status.nixos.org antes do primeiro `nix flake lock`.
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-26.05";
  };

  outputs =
    { self, nixpkgs }:
    let
      systems = [
        "x86_64-linux"
        "aarch64-linux"
        "x86_64-darwin"
        "aarch64-darwin"
      ];
      forAllSystems = f: nixpkgs.lib.genAttrs systems (system: f nixpkgs.legacyPackages.${system});

      # Versão do OCaml fixada explicitamente (arquitetura da implementação, §3.1).
      # Não usar o atalho `ocamlPackages`, que muda de versão quando o nixpkgs é atualizado.
      # Se alguma dependência não compilar com a 5.4, trocar por ocamlPackages_5_3.
      ocamlPackagesFor = pkgs: pkgs.ocaml-ng.ocamlPackages_5_4;
    in
    {
      devShells = forAllSystems (
        pkgs:
        let
          op = ocamlPackagesFor pkgs;
        in
        {
          default = pkgs.mkShell {
            name = "juscore-dev";

            # Compilador, build e ferramentas
            nativeBuildInputs = [
              op.ocaml
              op.findlib
              op.dune_3
              op.menhir
              op.ocaml-lsp
              op.ocamlformat
              pkgs.git
            ];

            # Bibliotecas usadas pela implementação
            buildInputs = [
              op.menhirLib # runtime dos parsers gerados pelo Menhir
              op.zarith # Nat, Tez, Timestamp
              op.yojson # saída JSON
              op.cmdliner # linha de comando
              op.alcotest # testes de unidade
            ];

            shellHook = ''
              echo "JusCore: OCaml $(ocaml -vnum), dune $(dune --version)"
            '';
          };
        }
      );
    };
}
