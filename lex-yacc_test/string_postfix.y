%{
#include<stdio.h>
#include<stdlib.h>
#include<string.h>
#include<ctype.h>
int yylex();
void yyerror(char* s);
%}

%union {
    char *c;
}

%token <c> WORD
%left '+'
%left '*'

%% 
start : expr '\n' {printf("\n"); exit(0);}
;
expr : expr '+' expr {printf("+ ");}
    | expr '*' expr {printf("* "); }
    | '(' expr ')' 
    | WORD {printf("%s ", $1); }
    ;
%%

void yyerror(char *s){printf("%s\n", s);}

int main(){
    yyparse();
    return 0;
}