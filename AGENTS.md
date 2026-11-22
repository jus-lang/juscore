# Instruções para agentes

Leia antes de qualquer alteração:
- docs/juscore-v0.1-language-definition.md (normativo para a linguagem)
- docs/juscore-v0.1-architecture.md (normativo para a implementação)

Regras:
1. Não altere arquivos em test/conformance/ nem em test/contracts/ sem
   aprovação explícita. Se um teste parecer errado, explique o motivo e pare.
2. Não adicione dependências (pacotes em flake.nix ou bibliotecas em
   arquivos dune) sem aprovação.
3. Trabalhe dentro do ambiente do projeto (nix develop).
4. Respeite as dependências entre bibliotecas da seção 4 da arquitetura.
5. Não use estado global mutável, exceto o coletor de diagnósticos.
6. Todo diagnóstico usa um código de lib/diagnostics/code.ml; não invente
   códigos. Se faltar um, pare e reporte.
7. Antes de concluir, rode `dune build` e `dune test` e informe o resultado.
8. Se encontrar ambiguidade na definição da linguagem, não decida sozinho:
   descreva a ambiguidade e as alternativas.
