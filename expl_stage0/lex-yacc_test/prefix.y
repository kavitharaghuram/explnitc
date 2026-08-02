%{
#include<stdio.h>
#include<stdlib.h>
#include<string.h>
void yyerror(char* s);
int yylex();
%}

%union{
    char* c;
}

%token <c> WORD
%left '+'
%left '*'

%%

start: expr '\n'
    {
        printf("\n");
        exit(0);
    };
expr : expr {printf("+ "); } '+' expr
    | expr { printf("* "); } '*' expr
    | '(' expr ')'
    | WORD { printf("%s ", $1);};

%%

void yyerror(char* s){
    printf("%s\n", s);
}
int main(){
    yyparse();
    return 0;
}