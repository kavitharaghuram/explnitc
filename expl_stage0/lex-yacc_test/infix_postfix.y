%{
#include<stdio.h>
#include<stdlib.h>
int yylex();
void yyerror(char* s);
%}
%union {
    char c;
}
%token <c> LETTER
%left '+'
%left '*'

%%
start: expr '\n' { printf("\n"); exit(0); }
    ;
expr: expr '+' expr {printf("%c", '+');}
    | expr '*' expr { printf("%c", '*'); }
    | '(' expr ')' 
    | LETTER { printf("%c", $1); }
    ;
%%

void yyerror(char* s){
    printf("%s\n", s);
}
int main(){
    yyparse();
    return 0;
}