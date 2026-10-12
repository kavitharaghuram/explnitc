%{
#include<stdio.h>
int yylex();
void yyerror(char* s);
%}
%token B

%%
start: N {printf("decimal=%d\n", $1);}
    ;
N: N B {
    $$= 2*$1 + $2;
}
    | B {$$=$1;}
    ;
%%
void yyerror(char* s){
    printf("invalid binary number\n");
}
int main(){
    yyparse();
}