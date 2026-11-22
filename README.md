[![License](https://img.shields.io/badge/License-Apache_2.0-blue.svg)](https://opensource.org/licenses/Apache-2.0)
# JusCore

Definição e implementação de referência do JusCore, uma linguagem funcional
para smart contracts em Tezos voltada a desenvolvimento agêntico e
verificável.

- Programa de pesquisa: [jus-lang/jus](https://codeberg.org/jus-lang/jus)
- Definição da linguagem: [docs/juscore-v0.1-language-definition.md](docs/juscore-v0.1-language-definition.md)
- Arquitetura da implementação: [docs/juscore-v0.1-architecture.md](docs/juscore-v0.1-architecture.md)
- Instruções para agentes: [AGENTS.md](AGENTS.md)

## Ambiente

Requer [Nix](https://nixos.org) com flakes habilitados
(`experimental-features = nix-command flakes` em `~/.config/nix/nix.conf`).

    nix develop                       # entra no ambiente
    nix develop --command dune build
    nix develop --command dune test

## Situação

Em desenvolvimento (marco M0). Ver arquitetura, §11.

## Licença

Este projeto está licenciado sob a licença Apache 2.0 - veja o arquivo [LICENSE](LICENSE) para mais detalhes.
