grammar Jus;

// Program Structure
program: (module_definition | contract_definition)*;

module_definition: 'module' IDENTIFIER 'where' definition*;

contract_definition: 'contract' IDENTIFIER 'where' definition*;

definition: type_definition
          | function_definition
          | state_definition
          | event_definition
          | transition_definition
          | struct_definition
          ;

// Type Definitions
type_definition: 'type' IDENTIFIER '=' type_expression;

type_expression
    : IDENTIFIER
    | type_expression '->' type_expression
    | type_expression '*' type_expression
    | 'Map' type_expression type_expression
    | 'Nat'
    | 'String'
    | 'Address'
    | 'Bool'
    | 'State'
    | 'Event'
    ;

// Function Definitions
function_definition: 'def' IDENTIFIER parameter_list? ':' type_expression ':=' expression;

parameter_list: '(' (parameter (',' parameter)*)? ')';

parameter: IDENTIFIER ':' type_expression;

// State Definitions
state_definition: 'inductive' 'State' 'where' state_constructor*;

state_constructor: '|' IDENTIFIER ':' 'State';

// Event Definitions
event_definition: 'inductive' 'Event' 'where' event_constructor*;

event_constructor: '|' IDENTIFIER ':' 'Event';

// Transition Definitions
transition_definition: 'def' 'transition' '(' IDENTIFIER ':' 'State' ')' '(' IDENTIFIER ':' 'Event' ')' ':' 'State' ':=' expression;

// Struct Definitions
struct_definition: 'structure' IDENTIFIER 'where' struct_field*;

struct_field: IDENTIFIER ':' type_expression;

// Expressions
expression: comparison_expression;

comparison_expression
    : member_access_expression
    | comparison_expression GT comparison_expression
    | comparison_expression LT comparison_expression
    | comparison_expression GTE comparison_expression
    | comparison_expression LTE comparison_expression
    | comparison_expression EQ_OP comparison_expression
    | comparison_expression NEQ comparison_expression
    ;

member_access_expression
    : primary_expression
    | member_access_expression DOT IDENTIFIER
    ;

primary_expression
    : IDENTIFIER
    | literal
    | function_call
    | match_expression
    | if_expression
    | '(' expression ')'
    ;

literal: NAT_LITERAL
       | STRING_LITERAL
       | BOOL_LITERAL
       ;

function_call: IDENTIFIER argument_list?;

argument_list: '(' (expression (',' expression)*)? ')';

match_expression: 'match' '(' expression (',' expression)* ')' 'with' match_case*;

match_case: '|' pattern '=>' expression;

pattern: IDENTIFIER
       | '(' pattern (',' pattern)* ')'
       | '_'
       ;

if_expression: 'if' '(' expression ')' 'then' expression 'else' expression;

// Lexer Rules
MODULE: 'module';
WHERE: 'where';
CONTRACT: 'contract';
TYPE: 'type';
DEF: 'def';
INDUCTIVE: 'inductive';
STATE: 'State';
TRANSITION: 'transition';
STRUCTURE: 'structure';
EVENT: 'Event';
MAP: 'Map';
NAT: 'Nat';
STRING: 'String';
ADDRESS: 'Address';
BOOL: 'Bool';
IF: 'if';
THEN: 'then';
ELSE: 'else';
MATCH: 'match';
WITH: 'with';

IDENTIFIER: [a-zA-Z_] [a-zA-Z0-9_]*;
NAT_LITERAL: [0-9]+;
STRING_LITERAL: '"' ( ~('"'|'\\') | '\\' . )* '"';
BOOL_LITERAL: 'true' | 'false';

// Comparison operators
GT: '>';
LT: '<';
GTE: '>=';
LTE: '<=';
EQ_OP: '==';
NEQ: '!=';

// Member access
DOT: '.';

ARROW: '->';
ASTERISK: '*';
EQ: '=';
COLON: ':';
LPAREN: '(';
RPAREN: ')';
PIPE: '|';
UNDERSCORE: '_';
COMMA: ',';
ASSIGN: ':=';

WS: [ \t\r\n]+ -> skip;

SINGLE_LINE_COMMENT: '--' .*? '\n' -> skip;
MULTI_LINE_COMMENT: '{-' .*? '-}' -> skip;