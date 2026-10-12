%{
#include<stdio.h>
int yylex();
void yyerror(char* s);
%}
%%
start: expr '\n' {printf("Balanced\n");}
    ;
expr: 
    | '(' expr ')' expr
    | '{' expr '}' expr
    ;


%%
void yyerror(char* s){
    printf("not balanced");
}
int yylex(){
    int c;
    while((c=getchar())==' ' || c=='\t');
    return c;
}
int main(){
    yyparse();
}