# JusCore v0.1 — Definição da Linguagem

|                             |                                                                                                                              |
|-----------------------------|------------------------------------------------------------------------------------------------------------------------------|
| **Status**                  | Rascunho para discussão (`0.1-draft3`)                                                                                       |
| **Data**                    | 2026-11-22                                                                                                                   |
| **Responsável**             | Jefferson O. Andrade                                                                                                         |
| **Público**                 | Grupo Jus; agentes de IA que irão gerar o front-end e o interpretador                                                        |
| **Documentos relacionados** | README do programa Jus (v7); *Arquitetura da implementação do JusCore* (`0.1-draft4`); *Protocolo experimental — Estudo 1* (`juscore-experiments`) |

---

## 0. Como ler este documento

Este documento é **normativo** para o front-end (lexer, parser, type checker) e para o interpretador de referência do JusCore v0.1. O artigo WorldCIST 2025 e o trabalho de 2025 sobre Jus são documentos de visão e **não** valem como especificação.

Convenções:

- **DEVE** / **NÃO DEVE** indicam requisitos obrigatórios.
- **PODE** indica comportamento permitido, mas opcional.
- *Informativo* marca seções explicativas, que não impõem requisitos.
- Mensagens de diagnóstico são em **inglês** (ver §10). O restante do documento é em português.
- Trechos de código usam a sintaxe do JusCore.
- Os termos *front-end*, *interpretador de referência*, *backend* e *compilador* têm o sentido definido na seção 1 da arquitetura da implementação.

Qualquer alteração neste documento deve ser registrada como decisão de design no Zulip (tópico `design decisions`), no formato `Decision / Rationale / Consequences`.

---

## 1. Escopo e objetivos

### 1.1 O que o v0.1 deve permitir

1. Escrever os contratos da suíte de referência (§11): TimeLockVault, Escrow e Multisig simples.
2. Fazer o parsing e a checagem de tipos desses contratos, com diagnósticos estruturados (§10).
3. Executá-los num interpretador de referência que simula transações (§8.4).
4. Expressar especificações `requires`/`ensures`, **checadas em tempo de execução** no v0.1 (§7).

### 1.2 O que o v0.1 não inclui

- backend para Michelson (vem depois do primeiro artigo; a §12 traz uma correspondência informativa);
- verificação estática de especificações (parte do trabalho de Sostenes; ponto de extensão em §7.4);
- os demais itens listados na §13.

### 1.3 Princípios aplicados

*Informativo.* As decisões deste documento seguem os princípios do programa de pesquisa:

- **Linguagem pequena:** é mais fácil de aprender pelo contexto, de implementar e de formalizar.
- **Uma forma para cada coisa:** uma só sintaxe de chamada, sem conversões implícitas e sem sobrecarga além da tabela aritmética (§6.6).
- **Insensível a layout:** indentação e quebras de linha não têm significado, e blocos terminam com `end`. Isso elimina uma classe inteira de erros de agentes.
- **Primeira ordem e sem recursão:** todo programa termina, o que simplifica o interpretador, a futura compilação para Michelson e a verificação. Esta é uma decisão para o v0.1 e está marcada para revisão (§1.4).
- **Modelo de execução do Michelson à vista:** um entrypoint recebe storage e contexto e devolve (operações, novo storage).
- **Especificação separada do corpo:** as cláusulas `requires`/`ensures` ficam entre a assinatura e o `:=`, o que permite a ferramentas detectar alterações nelas (princípio da especificação como ponto de autoridade humana).

### 1.4 Decisões validadas

Decisões de design validadas em 2026-11-22. As marcadas com **REVISAR** valem para o v0.1, mas devem ser reavaliadas antes do v0.2. O gatilho indica o que deve motivar a reavaliação.

| #  | Decisão                                                                     | Situação                           | Gatilho para revisão                                                                                                                                         |
|----|-----------------------------------------------------------------------------|------------------------------------|--------------------------------------------------------------------------------------------------------------------------------------------------------------|
| D1 | Sintaxe de chamada `f(a, b)`, e não justaposição `f a b`                    | Validada                           | —                                                                                                                                                            |
| D2 | Sintaxe insensível a layout, com blocos terminados por `end`                | Validada                           | —                                                                                                                                                            |
| D3 | `storage`, `ctx` e `result` implícitos nos entries; retorno sempre `Result` | Validada                           | —                                                                                                                                                            |
| D4 | Linguagem de primeira ordem (sem lambdas nem funções como valores)          | Validada para o v0.1 · **REVISAR** | Contrato da suíte ou tarefa do piloto que precise percorrer coleções (ex.: multisig com pesos por signatário)                                                |
| D5 | Sem recursão nem laços                                                      | Validada para o v0.1 · **REVISAR** | O mesmo de D4. Caminho preferido: primeiro, iteração limitada por built-ins (`fold` sobre `List`/`Map`), que preserva a terminação; recursão geral só depois |
| D6 | Sem tipo `Int`                                                              | Validada para o v0.1 · **REVISAR** | Contrato que precise de valores com sinal, ou início do backend (em Michelson, `nat - nat` produz `int`)                                                     |
| D7 | Chamadas a outros contratos ficam para o v0.2                               | Validada; documentada na §13.2     | Início do v0.2                                                                                                                                               |
| D8 | `Ops.total`/`Ops.sentTo` só em `requires`/`ensures`                         | Validada                           | —                                                                                                                                                            |
| D9 | Diagnósticos com conteúdo fixado e apresentação livre                       | Validada                           | —                                                                                                                                                            |

---

## 2. Visão geral (informativo)

Um arquivo `.jus` contém exatamente um contrato:

```jus
contract TimeLockVault

inductive State where
  | Locked
  | Claimed
end

structure Storage where
  owner      : Address
  unlockTime : Timestamp
  state      : State
end

entry withdraw()
  requires ctx.sender == storage.owner
  requires ctx.now >= storage.unlockTime
  requires storage.state == Locked
  requires ctx.amount == 0mutez
  ensures  result.storage.state == Claimed
  ensures  Ops.sentTo(result.ops, storage.owner) == ctx.balance
  ensures  Ops.total(result.ops) == ctx.balance
:=
  { ops     := [transfer(storage.owner, ctx.balance)],
    storage := { storage with state := Claimed } }
```

Dentro de um `entry`, três nomes são implícitos:

- `storage` — o storage antes da chamada;
- `ctx` — o contexto da transação;
- `result` — o valor devolvido; só pode aparecer em `ensures`.

---

## 3. Léxico

### 3.1 Codificação e arquivos

- O arquivo-fonte **DEVE** estar em UTF-8. A extensão é `.jus`.
- Caracteres fora do ASCII só são permitidos dentro de literais de string e de comentários (E001).

### 3.2 Espaços e comentários

- Espaços, tabulações e quebras de linha separam tokens e não têm outro significado.
- O comentário de linha começa com `--` e vai até o fim da linha.
- O comentário de bloco é `/- ... -/`. Não aninha. Se não for fechado, gera E003.

### 3.3 Identificadores

```
LIDENT ::= [a-z_][A-Za-z0-9_]*      -- variáveis, funções, campos, entries
UIDENT ::= [A-Z][A-Za-z0-9_]*       -- tipos, construtores, módulos embutidos
```

O identificador `_` sozinho é o curinga de padrões e não pode ser usado como nome de variável.

### 3.4 Palavras reservadas

```
contract structure inductive where end def entry requires ensures
let in if then else match with true false
```

Os nomes `storage`, `ctx` e `result` não são palavras-chave, mas são **reservados**: não podem ser usados como nome de parâmetro, de variável ou de campo de padrão (E207).

### 3.5 Literais

| Literal  | Forma                                | Tipo      | Observações                                                                          |
|----------|--------------------------------------|-----------|--------------------------------------------------------------------------------------|
| Booleano | `true`, `false`                      | `Bool`    |                                                                                      |
| Natural  | `[0-9][0-9_]*`                       | `Nat`     | Precisão arbitrária; `_` é separador visual (`1_000`)                                |
| Tez      | `NAT tz` ou `NAT mutez` (sem espaço) | `Tez`     | `5tz` = 5 000 000 mutez; `250mutez`. Estouro de 2^63−1 mutez gera E004               |
| String   | `"..."`                              | `String`  | Escapes: `\"`, `\\`, `\n`. Outros escapes geram E005; string não terminada gera E002 |
| Endereço | `@[A-Za-z0-9]+`                      | `Address` | Ex.: `@tz1VSUr8wwNhLAzempoch5d6hLRiTh8Cjcjb`. O v0.1 não valida o checksum           |

Um literal numérico seguido de letras que não formem `tz` ou `mutez` gera E004 (ex.: `5tez`).

### 3.6 Símbolos

```
( ) [ ] { } , : := . | => _ @
== != < <= > >= + - * / % && || !
```

---

## 4. Gramática

A gramática está em EBNF. `X*` significa zero ou mais, `X+` um ou mais, `[X]` opcional. Terminais aparecem entre aspas.

### 4.1 Programa e declarações

```ebnf
program        ::= "contract" UIDENT decl* EOF

decl           ::= structDecl | inductiveDecl | defDecl | entryDecl

structDecl     ::= "structure" UIDENT "where" field* "end"
field          ::= LIDENT ":" type

inductiveDecl  ::= "inductive" UIDENT "where" ctorDecl+ "end"
ctorDecl       ::= "|" UIDENT [ "(" field ( "," field )* ")" ]

defDecl        ::= "def" LIDENT "(" [ params ] ")" ":" type spec* ":=" expr
entryDecl      ::= "entry" LIDENT "(" [ params ] ")" spec* ":=" expr
params         ::= param ( "," param )*
param          ::= LIDENT ":" type

spec           ::= "requires" expr
                 | "ensures" expr
```

Observações:

- As declarações podem aparecer em qualquer ordem, e nomes podem ser usados antes de declarados (§6.1).
- Um `entry` não declara tipo de retorno: o tipo é sempre `Result` (§5.3).
- Uma expressão de `spec` termina onde começa o próximo `requires`, `ensures` ou `:=`.
- O corpo de `def`/`entry` termina onde começa a próxima declaração (`structure`, `inductive`, `def`, `entry`) ou em EOF.

### 4.2 Tipos

```ebnf
type           ::= UIDENT [ "[" type ( "," type )* "]" ]
```

Exemplos: `Nat`, `Option[Tez]`, `List[Address]`, `Map[Address, Bool]`.

### 4.3 Expressões

A precedência vai da mais baixa (topo da lista) para a mais alta.

```ebnf
expr           ::= "let" LIDENT [ ":" type ] ":=" expr "in" expr
                 | "if" expr "then" expr "else" expr
                 | "match" expr "with" arm+ "end"
                 | orExpr

arm            ::= "|" pattern "=>" expr
pattern        ::= "_"
                 | UIDENT [ "(" subpat ( "," subpat )* ")" ]
subpat         ::= "_" | LIDENT

orExpr         ::= andExpr ( "||" andExpr )*
andExpr        ::= cmpExpr ( "&&" cmpExpr )*
cmpExpr        ::= addExpr [ cmpOp addExpr ]          -- não associativo
cmpOp          ::= "==" | "!=" | "<" | "<=" | ">" | ">="
addExpr        ::= mulExpr ( ( "+" | "-" ) mulExpr )*  -- associativo à esquerda
mulExpr        ::= unary ( ( "*" | "/" | "%" ) unary )* -- associativo à esquerda
unary          ::= "!" unary
                 | postfix
postfix        ::= primary ( "." LIDENT )*

primary        ::= literal
                 | LIDENT                              -- variável
                 | LIDENT "(" [ args ] ")"             -- chamada de def ou built-in global
                 | UIDENT "." LIDENT "(" [ args ] ")"  -- built-in de módulo (ex.: List.length)
                 | UIDENT [ "(" args ")" ]             -- construtor
                 | "{" fieldInit ( "," fieldInit )* "}"            -- literal de registro
                 | "{" expr "with" fieldInit ( "," fieldInit )* "}" -- atualização de registro
                 | "[" [ args ] "]"                    -- literal de lista
                 | "(" expr ")"
                 | "(" expr ":" type ")"               -- anotação de tipo

args           ::= expr ( "," expr )*
fieldInit      ::= LIDENT ":=" expr
literal        ::= "true" | "false" | NAT | TEZ | STRING | ADDRESS
```

Observações:

- `let`, `if` e `match` só aparecem no nível mais externo de uma expressão. Para usá-los como operando, é preciso parênteses: `a + (if c then 1 else 2)`.
- O ramo `else` é obrigatório. O `else` se estende o máximo possível: `if c then a else b + 1` é lido como `if c then a else (b + 1)`.
- `match` sempre termina com `end`, por isso `match` aninhados não são ambíguos.
- Comparações não encadeiam: `a < b < c` gera E101.
- Um construtor sem campos é escrito sem parênteses (`Claimed`). Escrever `Claimed()` gera E303.
- `UIDENT "." ...` é sempre uma chamada de built-in de módulo. Construtores não têm campos acessíveis por `.`.

---

## 5. Tipos

### 5.1 Tipos embutidos

| Tipo        | Valores                                         | Comparável (§5.4)                     |
|-------------|-------------------------------------------------|---------------------------------------|
| `Bool`      | `true`, `false`                                 | `==`, `!=`                            |
| `Nat`       | naturais de precisão arbitrária                 | ordem total                           |
| `Tez`       | inteiros de 0 a 2^63−1, em mutez                | ordem total                           |
| `String`    | sequências de bytes UTF-8                       | ordem total (lexicográfica por bytes) |
| `Address`   | endereços opacos                                | `==`, `!=`                            |
| `Timestamp` | segundos desde a época Unix                     | ordem total                           |
| `Option[T]` | `Some(v)`, `None`                               | não                                   |
| `List[T]`   | listas finitas                                  | não                                   |
| `Map[K, V]` | mapas finitos; `K` deve ser comparável          | não                                   |
| `Operation` | operações emitidas (no v0.1, só transferências) | não                                   |

### 5.2 Tipos definidos pelo usuário

- **`structure`**: registro nominal com campos nomeados. Pode ter zero campos.
- **`inductive`**: soma nominal. Cada construtor tem zero ou mais campos tipados e posicionais; os nomes dos campos servem só como documentação.
- Um `inductive` cujos construtores não têm campos é uma **enumeração**.
- Tipos recursivos (diretos ou mútuos) não são permitidos (E311).
- Tipos do usuário não podem ter parâmetros de tipo.

### 5.3 Tipos especiais: `Storage`, `Context` e `Result`

- **`Storage`**: todo contrato **DEVE** declarar exatamente uma `structure Storage` (E501). Nenhum campo de `Storage` pode conter, direta ou transitivamente, o tipo `Operation` (E504).
- **`Context`** é um registro embutido com estes campos:

  | Campo     | Tipo        | Significado                                 |
  |-----------|-------------|---------------------------------------------|
  | `sender`  | `Address`   | quem chamou o entrypoint                    |
  | `amount`  | `Tez`       | valor enviado junto com a chamada           |
  | `balance` | `Tez`       | saldo do contrato **já incluindo** `amount` |
  | `now`     | `Timestamp` | horário do bloco                            |
  | `self`    | `Address`   | endereço do próprio contrato                |

- **`Result`** é um registro embutido com dois campos: `ops : List[Operation]` e `storage : Storage`.
- `Context` e `Result` não podem aparecer em campos de tipos do usuário nem em parâmetros (E504).

### 5.4 Comparabilidade

- **Igualdade** (`==`, `!=`) existe para `Bool`, `Nat`, `Tez`, `String`, `Address`, `Timestamp` e enumerações do usuário.
- **Ordem** (`<`, `<=`, `>`, `>=`) existe para `Nat`, `Tez`, `String` e `Timestamp`.
- **Chaves de `Map`** e o argumento de `List.contains` exigem tipos com igualdade (E304).
- Os demais tipos não são comparáveis. Para inspecioná-los, use `match`.

### 5.5 Igualdade de tipos

A igualdade é nominal para tipos do usuário e estrutural para os construtores embutidos (`List[Nat]` = `List[Nat]`). Não há subtipagem nem conversão implícita.

---

## 6. Boa formação e tipagem

### 6.1 Nomes e escopo

1. **Espaços de nomes:**
   - tipos (embutidos e do usuário);
   - construtores (`Some`, `None` e os do usuário);
   - funções (defs, entries e built-ins globais `transfer` e `fail`);
   - módulos embutidos (`Option`, `List`, `Map`, `Tez`, `Timestamp`, `Ops`).
2. **Unicidade:** dentro de cada espaço, nomes são únicos (E205). Um nome do usuário não pode coincidir com um nome embutido (E205).
3. **Construtores:** são únicos no contrato inteiro, mesmo pertencendo a tipos diferentes.
4. **Campos:** são únicos dentro de uma `structure` e dentro de um construtor (E206). Structures diferentes podem ter campos com o mesmo nome.
5. **Parâmetros:** os de um mesmo def ou entry são distintos (E206).
6. **Ordem:** declarações de nível superior valem no contrato inteiro, independentemente da posição.
7. **Sem sombreamento:** um `let`, parâmetro ou variável de padrão não pode reutilizar o nome de uma variável já em escopo (E211).
8. **`storage` e `ctx`:** só existem dentro de entries, inclusive nos seus `requires`/`ensures`. Em defs, geram E209.
9. **`result`:** só existe dentro de `ensures` (E208).
10. **Entries não são funções:** não podem ser chamados (E210).
11. **Sem recursão:** o grafo de chamadas entre defs **DEVE** ser acíclico (E309). Isso inclui auto-chamada e recursão mútua.
12. **Funções `Ops.*`:** só podem aparecer em `requires`/`ensures` (E601), porque operações são opacas em Michelson (§12).

### 6.2 Julgamentos

O type checker é **bidirecional**:

- `Γ ⊢ e ⇒ T` — a expressão `e` **sintetiza** o tipo `T`;
- `Γ ⊢ e ⇐ T` — a expressão `e` é **checada** contra o tipo esperado `T`.

`Γ` associa variáveis a tipos. As declarações globais (tipos, construtores, defs) ficam disponíveis implicitamente.

### 6.3 Regras de síntese (⇒)

| Expressão                                   | Regra                                                                                                                                                                   |
|---------------------------------------------|-------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| literais                                    | `true`/`false` ⇒ `Bool`; `NAT` ⇒ `Nat`; `TEZ` ⇒ `Tez`; `STRING` ⇒ `String`; `ADDRESS` ⇒ `Address`                                                                       |
| `x`                                         | `x : T ∈ Γ` ⇒ `T`; senão E201                                                                                                                                           |
| `e.f`                                       | `e ⇒ S`, sendo `S` uma structure, `Context` ou `Result` com campo `f : T` ⇒ `T`; senão E204                                                                             |
| `f(e₁,…,eₙ)` (def)                          | `def f(x₁:T₁,…,xₙ:Tₙ) : T`; cada `eᵢ ⇐ Tᵢ` ⇒ `T`; aridade errada gera E303                                                                                              |
| `C(e₁,…,eₙ)` (construtor do usuário de `D`) | cada `eᵢ ⇐` tipo do i-ésimo campo ⇒ `D`; aridade errada gera E303                                                                                                       |
| `Some(e)`                                   | `e ⇒ T` ⇒ `Option[T]`                                                                                                                                                   |
| `[e₁,…,eₙ]`, n ≥ 1                          | `e₁ ⇒ T`; `eᵢ ⇐ T` para i > 1 ⇒ `List[T]`                                                                                                                               |
| `{ e with f₁ := e₁, … }`                    | `e ⇒ S` (structure); cada `fᵢ` é campo de `S` (E204), sem repetição (E206); `eᵢ ⇐` tipo de `fᵢ` ⇒ `S`                                                                   |
| `(e : T)`                                   | `e ⇐ T` ⇒ `T`                                                                                                                                                           |
| built-ins                                   | conforme a §9                                                                                                                                                           |
| `e₁ op e₂` (aritmética)                     | `e₁ ⇒ T₁`, `e₂ ⇒ T₂`, consulta à tabela da §6.6; combinação ausente gera E302                                                                                           |
| `e₁ cmp e₂`                                 | `e₁ ⇒ T`, `e₂ ⇐ T`; `T` deve suportar `cmp` (§5.4), senão E302                                                                                                          |
| `e₁ && e₂`, `e₁ \|\| e₂`                    | `eᵢ ⇐ Bool` ⇒ `Bool`                                                                                                                                                    |
| `!e`                                        | `e ⇐ Bool` ⇒ `Bool`                                                                                                                                                     |
| `let x [: T] := e₁ in e₂`                   | com `T`: `e₁ ⇐ T`; sem `T`: `e₁ ⇒ T`. Depois, `Γ, x:T ⊢ e₂ ⇒ U` ⇒ `U`                                                                                                   |
| `if c then a else b`                        | `c ⇐ Bool`. Se `a` não for `fail(…)`: `a ⇒ T` e `b ⇐ T`. Se `a` for `fail(…)`: `b ⇒ T` e `a ⇐ T`. Os dois são `fail` ⇒ E305                                             |
| `match e with arms end`                     | `e ⇒ D` (inductive do usuário ou `Option[T]`), senão E404. O tipo do resultado é sintetizado pelo primeiro braço que não é `fail(…)`; os demais são checados contra ele |

Expressões que **não sintetizam** e geram E305 quando aparecem sem tipo esperado: `[]`, `None`, `Map.empty()`, literais de registro `{ f := … }` e `fail(…)`.

Uma comparação cujo operando esquerdo não sintetiza (ex.: `None == x`) gera E305. O conserto é anotar: `(None : Option[Nat]) == x`.

### 6.4 Regras de checagem (⇐ T)

| Expressão            | Regra                                                                                                                                            |
|----------------------|--------------------------------------------------------------------------------------------------------------------------------------------------|
| `[]`                 | `T = List[U]`                                                                                                                                    |
| `None`               | `T = Option[U]`                                                                                                                                  |
| `Map.empty()`        | `T = Map[K, V]`                                                                                                                                  |
| `{ f₁ := e₁, … }`    | `T` é uma structure ou `Result`; os campos são exatamente os de `T` (faltando: E306; sobrando: E307; repetidos: E206); cada `eᵢ ⇐` tipo do campo |
| `fail(s)`            | `s ⇐ String`; aceito para qualquer `T`                                                                                                           |
| `let`, `if`, `match` | o tipo esperado é propagado para o corpo, os ramos e os braços                                                                                   |
| qualquer outra       | `e ⇒ T'` e `T' = T`; senão E301, informando o tipo esperado e o encontrado                                                                       |

### 6.5 Padrões

- O *scrutinee* deve ter tipo inductive do usuário ou `Option[T]` (E404).
- `C(p₁,…,pₙ)`: `C` deve ser construtor do tipo do scrutinee (E403), com o mesmo número de subpadrões (E405). Cada subpadrão `x` liga uma variável com o tipo do campo correspondente; `_` não liga nada.
- `_` casa com qualquer valor.
- **Exaustividade:** se nenhum braço for `_`, todo construtor do tipo deve ter um braço; caso contrário, E401. A mensagem lista os construtores faltantes.
- **Redundância:** um braço depois de `_`, ou um segundo braço para o mesmo construtor, gera o aviso W402.
- Padrões não aninham: subpadrões são só variáveis ou `_`.

### 6.6 Aritmética

| Operador | Operandos                | Resultado              | Falha em tempo de execução       |
|----------|--------------------------|------------------------|----------------------------------|
| `+`      | `Nat, Nat`               | `Nat`                  | —                                |
| `+`      | `Tez, Tez`               | `Tez`                  | R007 (estouro)                   |
| `-`      | `Nat, Nat`               | `Nat`                  | R004 se o resultado for negativo |
| `-`      | `Tez, Tez`               | `Tez`                  | R004 se o resultado for negativo |
| `*`      | `Nat, Nat`               | `Nat`                  | —                                |
| `*`      | `Tez, Nat` ou `Nat, Tez` | `Tez`                  | R007                             |
| `/`      | `Nat, Nat`               | `Nat` (piso)           | R005 se o divisor for 0          |
| `/`      | `Tez, Nat`               | `Tez` (piso, em mutez) | R005                             |
| `%`      | `Nat, Nat`               | `Nat`                  | R005                             |

Qualquer outra combinação gera E302. A mensagem lista as combinações válidas para o operador e, quando houver uma correção óbvia, sugere-a (ex.: `5` → `5mutez`).

### 6.7 Declarações

- **def** `f(x₁:T₁,…,xₙ:Tₙ) : T`:
  - com `Γ = x₁:T₁,…,xₙ:Tₙ`, o corpo é checado contra `T`;
  - cada `requires` é checado contra `Bool` em `Γ`;
  - cada `ensures` é checado contra `Bool` em `Γ, result:T`.
- **entry** `e(x₁:T₁,…)`:
  - com `Γ = x₁:T₁,…, storage:Storage, ctx:Context`, o corpo é checado contra `Result`;
  - cada `requires` é checado contra `Bool` em `Γ`;
  - cada `ensures` é checado contra `Bool` em `Γ, result:Result`.
- **Avisos de especificação:**
  - uma cláusula que é literalmente `true` gera W602 (especificação trivial);
  - uma cláusula que é literalmente `false` gera W603.
- **Contrato:** deve ter pelo menos um entry (E502) e exatamente um cabeçalho `contract` (E103).

---

## 7. Especificações

### 7.1 Sintaxe

As cláusulas `requires` e `ensures` ficam entre a assinatura e o `:=`. Pode haver qualquer número delas, em qualquer ordem. A ordem importa para a execução (§8).

### 7.2 Significado no v0.1

No v0.1, todas as cláusulas são **checadas em tempo de execução**, tanto em entries quanto em defs:

- `requires` é avaliado antes do corpo. Se der `false`, a execução aborta com R001.
- `ensures` é avaliado depois do corpo, com `result` ligado ao valor devolvido. Se der `false`, a execução aborta com R002.

Num entry, `storage` dentro de um `ensures` continua sendo o storage **anterior** à chamada. O novo storage é `result.storage`. Como a linguagem é pura, não é preciso `old(…)` nem `modifies`.

### 7.3 Uso pretendido (informativo)

- `requires` em entries funciona como **guarda**. Quem chama um entry pode ser adversário, então a pré-condição precisa ser checada.
- `ensures` expressa propriedades de segurança que a implementação deve garantir. Exemplo: `ensures ctx.sender == storage.owner` num entry obriga a implementação a conter uma guarda de autorização. Se a guarda faltar, a chamada indevida é revertida em tempo de execução (R002).
- As funções `Ops.total` e `Ops.sentTo` (§9) permitem especificar **quem recebe quanto**, que é o tipo de propriedade que falhava nos exemplos legados.

### 7.4 Ponto de extensão para verificação estática

*Informativo; não é requisito do v0.1.* No futuro, o verificador do trabalho de Sostenes:

- tratará `requires` de entries como guardas, compiladas como `FAILWITH`, e provará os `ensures` sob essas guardas;
- tratará `requires` de defs como obrigação de prova de quem chama.

O front-end **DEVE** preservar na AST as cláusulas, na ordem e com suas localizações, para que esse trabalho possa usá-las sem alterar o parser.

---

## 8. Semântica operacional

### 8.1 Valores

- **Valores atômicos:** booleanos, naturais, tez (inteiro de mutez), strings, endereços, timestamps (inteiro de segundos).
- **Valores compostos:** listas, mapas (finitos e ordenados pela chave), opções, registros, valores de construtor e operações `Transfer(to, amount)`.

### 8.2 Avaliação de expressões

A semântica é de passo grande. O julgamento `ρ ⊢ e ⇓ v` significa que, no ambiente `ρ`, a expressão `e` avalia para o valor `v`. O julgamento `ρ ⊢ e ⇓ abort(r)` significa que ela aborta com o motivo `r` (um código R, §10.4, e uma mensagem).

- **Avaliação estrita**, da esquerda para a direita: argumentos de chamadas, operandos, elementos de listas e campos de registros na ordem em que aparecem no texto.
- **Curto-circuito:** `&&` e `||` avaliam o segundo operando somente se necessário.
- **`if`** avalia somente o ramo escolhido.
- **`match`** avalia o scrutinee e depois o primeiro braço cujo padrão casa.
- **`let`** avalia a definição e depois o corpo.
- **Propagação de abort:** qualquer abort interrompe a avaliação inteira; não existe mecanismo de captura.
- **`fail(s)`** aborta com R003 e a mensagem `s`.
- **Chamada de def:**
  1. avalia os argumentos;
  2. avalia os `requires` em ordem; o primeiro `false` aborta com R001, identificando o def e o índice da cláusula;
  3. avalia o corpo, obtendo `v`;
  4. avalia os `ensures` com `result = v`; o primeiro `false` aborta com R002;
  5. devolve `v`.
- **Aritmética:** conforme a §6.6, inclusive as falhas.

Como não há recursão nem laços, toda avaliação termina.

### 8.3 Execução de um entry

Dados o storage `s`, o contexto `c` e os argumentos `v₁…vₙ`:

1. `ρ = { x₁ ↦ v₁, …, storage ↦ s, ctx ↦ c }`;
2. avalia os `requires` em ordem; o primeiro `false` gera R001;
3. avalia o corpo, obtendo `r : Result`;
4. avalia os `ensures` em `ρ ∪ { result ↦ r }`; o primeiro `false` gera R002;
5. devolve `r`.

### 8.4 Semântica de transação (interpretador de referência)

O interpretador mantém um *ledger* simulado: o saldo de cada endereço, o storage do contrato e o seu saldo `B`. Uma chamada `call(entry, args, sender, amount, now)` funciona assim:

1. `B' := B + amount`; estouro gera R007.
2. `ctx := { sender, amount, balance := B', now, self }`.
3. Executa o entry (§8.3), obtendo `r`.
4. Processa `r.ops` **em ordem**. Para cada `Transfer(to, x)`: se `B' < x`, R006; senão, `B' := B' − x` e o saldo de `to` aumenta em `x`.
5. **Commit:** `storage := r.storage` e `B := B'`.

Se **qualquer** passo abortar, a transação é revertida por completo: o storage não muda, nenhum saldo muda (o `amount` volta a quem enviou) e nenhuma operação é executada. O resultado da chamada é o código e a mensagem do abort.

No v0.1, o interpretador trata qualquer endereço como capaz de receber tez e não executa código de outros contratos.

O formato de cenários (storage inicial, sequência de chamadas e resultados esperados) está definido na arquitetura da implementação, §8.

---

## 9. Biblioteca embutida

| Nome                    | Assinatura                                       | Falha | Observações                                                                        |
|-------------------------|--------------------------------------------------|-------|------------------------------------------------------------------------------------|
| `transfer`              | `(Address, Tez) → Operation`                     | —     | A falha de saldo acontece só na execução da transação (R006)                       |
| `fail`                  | `(String) → T` (qualquer tipo; só em modo check) | R003  |                                                                                    |
| `Some`                  | `(T) → Option[T]`                                | —     | Construtor                                                                         |
| `None`                  | `Option[T]` (só em modo check)                   | —     | Construtor                                                                         |
| `Option.isSome`         | `(Option[T]) → Bool`                             | —     |                                                                                    |
| `Option.getOr`          | `(Option[T], T) → T`                             | —     |                                                                                    |
| `List.length`           | `(List[T]) → Nat`                                | —     |                                                                                    |
| `List.contains`         | `(List[T], T) → Bool`                            | —     | `T` com igualdade (E304)                                                           |
| `List.cons`             | `(T, List[T]) → List[T]`                         | —     |                                                                                    |
| `Map.empty`             | `() → Map[K, V]` (só em modo check)              | —     | `K` comparável                                                                     |
| `Map.get`               | `(Map[K, V], K) → Option[V]`                     | —     |                                                                                    |
| `Map.contains`          | `(Map[K, V], K) → Bool`                          | —     |                                                                                    |
| `Map.put`               | `(Map[K, V], K, V) → Map[K, V]`                  | —     | Substitui o valor se a chave já existir                                            |
| `Map.remove`            | `(Map[K, V], K) → Map[K, V]`                     | —     | Não faz nada se a chave não existir                                                |
| `Map.size`              | `(Map[K, V]) → Nat`                              | —     |                                                                                    |
| `Tez.fromMutez`         | `(Nat) → Tez`                                    | R007  |                                                                                    |
| `Tez.toMutez`           | `(Tez) → Nat`                                    | —     |                                                                                    |
| `Timestamp.fromSeconds` | `(Nat) → Timestamp`                              | —     |                                                                                    |
| `Timestamp.addSeconds`  | `(Timestamp, Nat) → Timestamp`                   | —     |                                                                                    |
| `Ops.total`             | `(List[Operation]) → Tez`                        | R007  | **Só em `requires`/`ensures`** (E601). Soma dos valores transferidos               |
| `Ops.sentTo`            | `(List[Operation], Address) → Tez`               | R007  | **Só em `requires`/`ensures`** (E601). Soma do que foi transferido para o endereço |

**Tipagem dos built-ins:**

- **Monomórficos** (ex.: `transfer`, `Tez.fromMutez`, `Ops.total`): cada argumento é checado contra o tipo do parâmetro.
- **Polimórficos** (`Option.*`, `List.*`, `Map.*`): o **primeiro** argumento é sintetizado e instancia as variáveis de tipo. Os demais são checados contra a instância. Se o primeiro argumento não sintetizar (ex.: `List.length([])`), o erro é E305, e o conserto sugerido é uma anotação.

---

## 10. Diagnósticos

Os diagnósticos são o objeto da pergunta de pesquisa do Gelinton. Por isso, este documento fixa o **conteúdo** de cada diagnóstico (código, informação obrigatória), mas não a sua **apresentação**. As variantes de apresentação comparadas no experimento ficam definidas no protocolo experimental. Todas elas **DEVEM** ser geradas a partir do mesmo registro interno.

### 10.1 Registro interno de diagnóstico

| Campo                | Obrigatório   | Conteúdo                                                                                                             |
|----------------------|---------------|----------------------------------------------------------------------------------------------------------------------|
| `code`               | sim           | código estável (§10.3); nunca é reutilizado para outro significado                                                   |
| `severity`           | sim           | `error` ou `warning`                                                                                                 |
| `message`            | sim           | frase curta em inglês, sem jargão interno do compilador                                                              |
| `span`               | sim           | arquivo e posições de início (inclusiva) e fim (exclusiva); linha e coluna a partir de 1, com colunas em bytes UTF-8 |
| `expected` / `found` | quando houver | tipos envolvidos, impressos na sintaxe do JusCore                                                                    |
| `notes`              | não           | informações adicionais (ex.: as combinações válidas de um operador)                                                  |
| `related`            | não           | outras localizações com uma mensagem cada (ex.: "`State` declared here")                                             |
| `fixes`              | não           | correções sugeridas, cada uma com descrição e edições de texto aplicáveis (span + texto de substituição)             |

### 10.2 Saída

O front-end **DEVE** oferecer pelo menos dois formatos:

- **humano:** texto com o código, a mensagem, a localização e um trecho do código-fonte com a região marcada;
- **JSON:** uma lista de objetos com os campos da §10.1.

A forma de chamada (opções de linha de comando) está definida na arquitetura da implementação, §7.

**Recuperação:**

- **Erros léxicos e de sintaxe:** no v0.1, a análise **PODE** parar no primeiro. Nesse caso, as fases seguintes não rodam.
- **Demais erros** (da resolução de nomes em diante): a análise **DEVE** reportar todos os erros independentes que encontrar numa execução, e não só o primeiro.
- **Erros em cascata** devem ser suprimidos. Por exemplo, depois de um E202 (tipo desconhecido), não se reportam E301 que decorram apenas dele.

### 10.3 Catálogo de erros e avisos de compilação

| Código | Categoria     | Condição                                             | Exemplo de mensagem                                                     |
|--------|---------------|------------------------------------------------------|-------------------------------------------------------------------------|
| E001   | léxico        | caractere inválido                                   | `invalid character '§'`                                                 |
| E002   | léxico        | string não terminada                                 | `unterminated string literal`                                           |
| E003   | léxico        | comentário de bloco não terminado                    | `unterminated block comment`                                            |
| E004   | léxico        | literal numérico inválido ou estouro de tez          | `invalid numeric literal '5tez'; did you mean '5tz'?`                   |
| E005   | léxico        | escape inválido                                      | `invalid escape sequence '\t'`                                          |
| E101   | sintaxe       | token inesperado                                     | `unexpected 'then'; expected one of: expression`                        |
| E102   | sintaxe       | bloco sem `end`                                      | `'match' starting here is not closed with 'end'`                        |
| E103   | sintaxe       | cabeçalho `contract` ausente ou repetido             | `a file must start with exactly one 'contract' header`                  |
| E201   | nomes         | nome desconhecido                                    | `unknown name 'ownr'; did you mean 'owner'?`                            |
| E202   | nomes         | tipo desconhecido                                    | `unknown type 'Natural'; did you mean 'Nat'?`                           |
| E203   | nomes         | construtor desconhecido                              | `unknown constructor 'Unlocked'`                                        |
| E204   | nomes         | campo desconhecido                                   | `type 'Storage' has no field 'balance'`                                 |
| E205   | nomes         | definição duplicada ou em conflito com nome embutido | `'Some' is a built-in constructor and cannot be redefined`              |
| E206   | nomes         | campo ou parâmetro repetido                          | `field 'owner' is declared twice`                                       |
| E207   | nomes         | nome reservado usado como variável                   | `'storage' is reserved and cannot be used as a variable name`           |
| E208   | nomes         | `result` fora de `ensures`                           | `'result' is only available in 'ensures' clauses`                       |
| E209   | nomes         | `storage`/`ctx` fora de entry                        | `'ctx' is only available inside entries; pass the value as a parameter` |
| E210   | nomes         | entry chamado como função                            | `entry 'withdraw' cannot be called as a function`                       |
| E211   | nomes         | sombreamento                                         | `variable 'x' is already defined in this scope`                         |
| E301   | tipos         | tipo incompatível                                    | `type mismatch: expected 'Tez', found 'Nat'`                            |
| E302   | tipos         | operador não definido para os tipos                  | `operator '+' is not defined for 'Tez' and 'Nat'`                       |
| E303   | tipos         | número errado de argumentos                          | `'transfer' expects 2 arguments, found 1`                               |
| E304   | tipos         | tipo sem igualdade onde ela é exigida                | `map keys must be comparable; 'List[Nat]' is not`                       |
| E305   | tipos         | tipo não inferível                                   | `cannot infer the type of '[]'; add a type annotation`                  |
| E306   | tipos         | campo faltando em literal de registro                | `missing field 'state' in 'Storage' literal`                            |
| E307   | tipos         | campo sobrando em literal de registro                | `'Result' has no field 'extra'`                                         |
| E309   | tipos         | ciclo de chamadas                                    | `recursive call cycle: f -> g -> f; recursion is not allowed`           |
| E311   | tipos         | tipo recursivo                                       | `type 'Tree' refers to itself; recursive types are not allowed`         |
| E401   | padrões       | match não exaustivo                                  | `match is not exhaustive: missing 'Cancelled'`                          |
| W402   | padrões       | braço inalcançável                                   | `unreachable match arm`                                                 |
| E403   | padrões       | construtor de outro tipo                             | `constructor 'Locked' belongs to 'VaultState', not 'State'`             |
| E404   | padrões       | match sobre tipo não indutivo                        | `cannot match on a value of type 'Nat'`                                 |
| E405   | padrões       | número errado de subpadrões                          | `'Pending' has 2 fields, pattern has 1`                                 |
| E501   | contrato      | `structure Storage` ausente                          | `contract must declare 'structure Storage'`                             |
| E502   | contrato      | nenhum entry                                         | `contract must declare at least one entry`                              |
| E504   | contrato      | tipo não permitido no lugar                          | `'Operation' cannot be stored in 'Storage'`                             |
| E601   | especificação | `Ops.*` fora de `requires`/`ensures`                 | `'Ops.total' can only be used in 'requires' or 'ensures'`               |
| W602   | especificação | cláusula trivialmente verdadeira                     | `'ensures true' states nothing`                                         |
| W603   | especificação | cláusula trivialmente falsa                          | `'requires false' makes this entry uncallable`                          |

### 10.4 Catálogo de falhas em tempo de execução

| Código | Condição                              | Informação obrigatória                             |
|--------|---------------------------------------|----------------------------------------------------|
| R001   | `requires` falso                      | entry ou def, índice da cláusula, span da cláusula |
| R002   | `ensures` falso                       | entry ou def, índice da cláusula, span da cláusula |
| R003   | `fail(s)`                             | mensagem `s`, span                                 |
| R004   | subtração negativa (`Nat`/`Tez`)      | operandos, span                                    |
| R005   | divisão ou resto por zero             | span                                               |
| R006   | saldo insuficiente para transferência | saldo, valor, destino                              |
| R007   | estouro de `Tez`                      | span                                               |

### 10.5 Exemplo de diagnóstico (JSON)

Suponha que, no TimeLockVault da §11.1, a linha 26 (`requires ctx.amount == 0mutez`, em `withdraw`) seja trocada por `requires ctx.amount == 5`. O diagnóstico esperado é:

```json
{
  "code": "E301",
  "severity": "error",
  "message": "type mismatch: expected 'Tez', found 'Nat'",
  "span": { "file": "vault.jus",
            "start": { "line": 26, "col": 26 },
            "end":   { "line": 26, "col": 27 } },
  "expected": "Tez",
  "found": "Nat",
  "notes": ["the left operand 'ctx.amount' has type 'Tez'"],
  "fixes": [
    { "description": "write the amount in mutez",
      "edits": [ { "span": { "start": { "line": 26, "col": 26 },
                             "end":   { "line": 26, "col": 27 } },
                   "text": "5mutez" } ] },
    { "description": "write the amount in tez",
      "edits": [ { "span": { "start": { "line": 26, "col": 26 },
                             "end":   { "line": 26, "col": 27 } },
                   "text": "5tz" } ] }
  ]
}
```

---

## 11. Contratos de referência

Os três contratos abaixo **DEVEM** ser aceitos pelo front-end, sem erros nem avisos. Eles formam o núcleo da suíte de testes.

### 11.1 TimeLockVault

```jus
contract TimeLockVault

inductive State where
  | Locked
  | Claimed
end

structure Storage where
  owner      : Address
  unlockTime : Timestamp
  state      : State
end

entry deposit()
  requires storage.state == Locked
  requires ctx.amount > 0mutez
  ensures  result.storage.state == storage.state
  ensures  Ops.total(result.ops) == 0mutez
:=
  { ops := [], storage := storage }

entry withdraw()
  requires ctx.sender == storage.owner
  requires ctx.now >= storage.unlockTime
  requires storage.state == Locked
  requires ctx.amount == 0mutez
  ensures  result.storage.state == Claimed
  ensures  Ops.sentTo(result.ops, storage.owner) == ctx.balance
  ensures  Ops.total(result.ops) == ctx.balance
:=
  { ops     := [transfer(storage.owner, ctx.balance)],
    storage := { storage with state := Claimed } }
```

> **Nota:** a pós-condição natural de `deposit` seria `ensures result.storage == storage`, mas `Storage` não é comparável (§5.4), e essa cláusula geraria E302. Por isso o contrato usa `result.storage.state == storage.state`. Ver Q1 na §14.

Em relação ao contrato legado, mudou o seguinte:

- o estado `Unlocked` foi eliminado, porque ele é derivado do tempo;
- o dono passa a ser checado;
- os fundos passam a ser efetivamente transferidos;
- o envio de tez junto com `withdraw` é proibido.

### 11.2 Escrow

```jus
contract Escrow

inductive State where
  | AwaitingPayment
  | AwaitingDelivery
  | Complete
  | Cancelled
end

structure Storage where
  buyer  : Address
  seller : Address
  price  : Tez
  state  : State
end

entry pay()
  requires ctx.sender == storage.buyer
  requires storage.state == AwaitingPayment
  requires ctx.amount == storage.price
  ensures  result.storage.state == AwaitingDelivery
  ensures  Ops.total(result.ops) == 0mutez
:=
  { ops := [], storage := { storage with state := AwaitingDelivery } }

entry confirmDelivery()
  requires ctx.sender == storage.buyer
  requires storage.state == AwaitingDelivery
  requires ctx.amount == 0mutez
  ensures  result.storage.state == Complete
  ensures  Ops.sentTo(result.ops, storage.seller) == storage.price
  ensures  Ops.total(result.ops) == storage.price
:=
  { ops     := [transfer(storage.seller, storage.price)],
    storage := { storage with state := Complete } }

entry cancel()
  requires ctx.amount == 0mutez
  ensures  result.storage.state == Cancelled
  ensures  Ops.sentTo(result.ops, storage.buyer) == Ops.total(result.ops)
  ensures  Ops.total(result.ops) <= storage.price
:=
  match storage.state with
  | AwaitingPayment =>
      if ctx.sender == storage.buyer || ctx.sender == storage.seller
      then { ops := [], storage := { storage with state := Cancelled } }
      else fail("only the buyer or the seller can cancel")
  | AwaitingDelivery =>
      if ctx.sender == storage.seller
      then { ops     := [transfer(storage.buyer, storage.price)],
             storage := { storage with state := Cancelled } }
      else fail("only the seller can cancel after payment")
  | Complete  => fail("escrow already completed")
  | Cancelled => fail("escrow already cancelled")
  end
```

Em relação ao contrato legado, mudou o seguinte:

- o pagamento é o valor realmente enviado (`ctx.amount`);
- a confirmação de entrega só pode vir do comprador;
- o cancelamento depois do pagamento só pode vir do vendedor e reembolsa o comprador;
- os fundos se movem de fato.

### 11.3 Multisig simples

```jus
contract Multisig

structure Storage where
  signers   : List[Address]
  threshold : Nat
  approvals : Map[Address, Bool]
  recipient : Address
  amount    : Tez
  executed  : Bool
end

entry approve()
  requires List.contains(storage.signers, ctx.sender)
  requires !storage.executed
  requires ctx.amount == 0mutez
  ensures  Map.contains(result.storage.approvals, ctx.sender)
  ensures  Ops.total(result.ops) == 0mutez
:=
  { ops     := [],
    storage := { storage with
                 approvals := Map.put(storage.approvals, ctx.sender, true) } }

entry execute()
  requires !storage.executed
  requires Map.size(storage.approvals) >= storage.threshold
  requires ctx.amount == 0mutez
  ensures  result.storage.executed
  ensures  Ops.sentTo(result.ops, storage.recipient) == storage.amount
  ensures  Ops.total(result.ops) == storage.amount
:=
  { ops     := [transfer(storage.recipient, storage.amount)],
    storage := { storage with executed := true } }
```

Como só signatários conseguem aprovar, `Map.size(storage.approvals)` conta aprovações distintas de signatários válidos. Um tipo `Set` fica para depois (§13).

### 11.4 Exemplos inválidos

**Match não exaustivo.** Retirando o braço `Cancelled` de `Escrow.cancel`, o resultado esperado é:

```
error[E401]: match is not exhaustive: missing 'Cancelled'
  --> escrow.jus:43:3
   |
43 |   match storage.state with
   |   ^^^^^^^^^^^^^^^^^^^^^^^^ 'Cancelled' is not covered
   |
note: 'State' declared here (escrow.jus:3:11)
help: add an arm: '| Cancelled => ...'
```

**Tipo incompatível.** Com `requires ctx.amount == 5` em `TimeLockVault.withdraw`, o resultado esperado é o E301 da §10.5.

**Variantes de segurança (falham em tempo de execução, não na compilação).** Retirar `requires ctx.sender == storage.owner` de `withdraw` produz um contrato bem tipado que qualquer endereço consegue esvaziar a favor do dono. Essas variantes vão para a suíte de cenários, com o resultado esperado de cada chamada. Elas ilustram por que a especificação aprovada por humanos tem de incluir as propriedades de autorização.

### 11.5 Casos de conformidade (amostra)

Os trechos abaixo supõem um contrato mínimo válido em volta deles: cabeçalho `contract`, `structure Storage` e pelo menos um entry. A lista completa será mantida na suíte de testes.

| Trecho                                                        | Resultado esperado |
|---------------------------------------------------------------|--------------------|
| `entry e() := { ops := [], storage := storage }`              | aceito             |
| `def f(x : Nat) : Nat := f(x)`                                | E309               |
| `def g(x : Nat) : Nat := let x := 1 in x`                     | E211               |
| `def h() : Nat := List.length([])`                            | E305               |
| `def k(a : Address) : Bool := a < a`                          | E302               |
| `def n() : Timestamp := ctx.now`                              | E209               |
| `entry e() := { ops := [], storage := storage, extra := 1 }`  | E307               |
| `entry e() ensures true := { ops := [], storage := storage }` | W602               |
| `def o(l : List[Operation]) : Tez := Ops.total(l)`            | E601               |
| `structure Storage where pending : List[Operation] end`       | E504               |
| `inductive T where \| A \| Some end`                          | E205               |
| `def m(x : Nat) : Bool := match x with \| _ => true end`      | E404               |
| execução de `def d() : Nat := 1 - 2`                          | R004               |
| execução de `def z() : Nat := 10 / 0`                         | R005               |

---

## 12. Correspondência com Michelson (informativo)

Esta seção não impõe requisitos ao v0.1. Ela serve para garantir que nenhuma decisão do v0.1 impeça o backend futuro.

| JusCore                                         | Michelson                                                                  |
|-------------------------------------------------|----------------------------------------------------------------------------|
| `Bool`, `Nat`, `String`, `Address`, `Timestamp` | `bool`, `nat`, `string`, `address`, `timestamp`                            |
| `Tez`                                           | `mutez` (por isso o limite de 2^63−1)                                      |
| `Option[T]`, `List[T]`, `Map[K, V]`             | `option`, `list`, `map` (`big_map` fica para depois)                       |
| `structure`                                     | `pair` aninhado                                                            |
| `inductive`                                     | `or` aninhado sobre `unit`/`pair`                                          |
| entries                                         | árvore `or` de parâmetros, com anotações de entrypoint                     |
| `Result`                                        | `pair (list operation) storage`                                            |
| `transfer(a, x)`                                | `CONTRACT unit` + `TRANSFER_TOKENS`; falha se o destino não aceitar `unit` |
| `fail(s)`                                       | `PUSH string s; FAILWITH`                                                  |
| `requires` em entry                             | teste seguido de `FAILWITH`                                                |
| `ensures`                                       | OPEN: assert em tempo de execução ou remoção após verificação              |
| `Ops.*`                                         | sem equivalente: operações são opacas em Michelson, daí a restrição E601   |
| `ctx.balance`                                   | `BALANCE` (inclui o `AMOUNT` da chamada corrente)                          |
| defs                                            | inlining ou `LAMBDA`; sem recursão, não há necessidade de `LOOP`           |

---

## 13. Fora do escopo do v0.1

| Recurso                                              | Situação                 | Motivo                                            |
|------------------------------------------------------|--------------------------|---------------------------------------------------|
| Chamadas a outros contratos (operação com parâmetro) | v0.2                     | Ver §13.2                                         |
| Tipo `Int`                                           | LATER · **REVISAR** (D6) | A suíte não precisa; evita conversões `Nat`/`Int` |
| `Set[T]`, literais de mapa                           | LATER                    | `Map[K, Bool]` resolve no v0.1                    |
| Funções de ordem superior, lambdas, `fold`           | LATER · **REVISAR** (D4) | Mantém a linguagem de primeira ordem              |
| Recursão, laços                                      | LATER · **REVISAR** (D5) | Garantia de terminação                            |
| Padrões aninhados e literais em padrões              | LATER                    |                                                   |
| Módulos do usuário                                   | LATER                    |                                                   |
| Eventos (emissão)                                    | LATER                    |                                                   |
| `aborts_if`                                          | LATER                    | Previsto no programa de pesquisa                  |
| Invariantes e propriedades no nível do contrato      | LATER                    |                                                   |
| Quantificadores em especificações                    | LATER                    |                                                   |
| Refinement types                                     | LATER                    | Como açúcar sintático sobre `requires`            |
| Sistema de efeitos                                   | OPEN                     |                                                   |
| Tipos dependentes, universos                         | Fora dos mestrados       |                                                   |
| Avaliação preguiçosa                                 | Removida                 |                                                   |
| `modifies`                                           | Removida                 | Redundante numa linguagem pura                    |

### 13.1 Divergências em relação ao programa de pesquisa v2

1. **Chamadas a contratos:** o programa classificava "operações (transferência; chamada de contrato)" como CORE. No v0.1 só há transferência; chamadas a contratos passam para o v0.2 (§13.2).
2. **Esboço do Apêndice A:** o programa usava `entry withdraw (s : Storage) (ctx : Context) : List Operation × Storage`. Agora `storage` e `ctx` são implícitos nos entries, o tipo de retorno é `Result`, e a sintaxe de chamada é `f(a, b)`.
3. **Checagem das especificações:** no v0.1, todos os `requires`, inclusive os de defs, são checados em tempo de execução. A distinção entre guarda (em entries) e obrigação de prova (em defs) fica para a verificação estática.
4. **`Int`:** o programa classificava `Int` entre os tipos básicos do Core. No v0.1 ele não existe (D6).

### 13.2 Chamadas a outros contratos (planejado para o v0.2)

**O que o v0.1 permite.** A única operação é `transfer(to, amount)`, que envia tez a um endereço. O interpretador trata todo endereço como capaz de receber tez e não executa código no destino (§8.4). No backend futuro, uma transferência para um contrato só funcionará se o destino aceitar `unit` no entrypoint padrão.

**O que fica de fora do v0.1:**

- chamar entrypoints de outros contratos passando parâmetros;
- consultar *views* de outros contratos;
- criar contratos a partir de um contrato;
- receber *callbacks*.

**Consequências para o v0.1:**

- não há composição entre contratos;
- em particular, não é possível transferir tokens FA1.2/FA2, porque isso exige chamar o contrato do token;
- os três contratos de referência (§11) não são afetados, porque só movem tez;
- tarefas do piloto que envolvam tokens ou composição devem esperar o v0.2.

**O que o v0.2 terá de definir:**

1. Um tipo para referências tipadas a contratos (ex.: `Contract[P]`) e uma forma de declarar a interface do contrato chamado.
2. Como obter uma referência a partir de um `Address`, com falha quando o destino não tiver o entrypoint esperado. Em Michelson, isso corresponde a `CONTRACT`, que devolve uma opção.
3. Uma operação de chamada (ex.: `call(c, args, amount) : Operation`) e sua tipagem.
4. Um ledger com vários contratos no interpretador e a ordem de execução das operações emitidas. Em Tezos, essas operações são executadas em profundidade, depois que o chamador termina.
5. O efeito sobre as especificações: o que um `ensures` pode afirmar quando o resultado depende do contrato chamado, e como `Ops.sentTo`/`Ops.total` contam os valores enviados em chamadas.
6. Novas propriedades de segurança relevantes (ex.: ordem de atualização do storage em relação às chamadas emitidas).

---

## 14. Questões abertas

| #  | Questão                                                                                                         | Proposta inicial                                                                                               |
|----|-----------------------------------------------------------------------------------------------------------------|----------------------------------------------------------------------------------------------------------------|
| Q1 | Permitir `==` sobre `structure` e inductives com campos? É útil em `ensures` (ex.: `result.storage == storage`) | Permitir igualdade estrutural **só** em `requires`/`ensures`, que em Michelson não precisam virar código       |
| Q2 | Sintaxe de chamada `f(a, b)` (adotada) ou aplicação por justaposição `f a b`, como no Lean?                     | Manter `f(a, b)`: é menos ambígua e mais familiar; avaliar no piloto                                           |
| Q3 | Formato de valores para storage inicial e argumentos nos cenários                                               | **Decidido:** literais e expressões JusCore, num formato de cenário próprio (arquitetura da implementação, §8) |
| Q4 | `ensures` no backend: assert em tempo de execução ou remoção após verificação?                                  | Decidir com o Sostenes                                                                                         |
| Q5 | Validar o checksum de endereços no front-end?                                                                   | Não no v0.1                                                                                                    |
| Q6 | Avisar quando um entry aceita tez sem `requires` sobre `ctx.amount`?                                            | Candidato a aviso no v0.2 (risco comum de fundos presos)                                                       |
| Q7 | Número de colunas em bytes ou em pontos de código Unicode?                                                      | Bytes no v0.1, já que identificadores são ASCII                                                                |

---

## Histórico

- `0.1-draft1` (2026-11-22): primeira versão completa para discussão.
- `0.1-draft2` (2026-11-22): registro das decisões validadas (§1.4); D4–D6 marcadas para revisão; nova §13.2 sobre chamadas a outros contratos no v0.2; divergência sobre `Int` registrada na §13.1.
- `0.1-draft3` (2026-11-22): terminologia alinhada com a arquitetura da implementação; Q3 decidida (formato de cenários); recuperação de erros léxicos e de sintaxe flexibilizada no v0.1 (§10.2).
