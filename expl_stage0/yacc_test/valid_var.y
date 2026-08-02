%{
#include<stdio.h>
#include<ctype.h>
int yylex();
void yyerror(char* s);
%}
%token LETTER DIGIT

%%
var : LETTER rest '\n' { printf("valid variable\n"); }
rest : rest LETTER
    | rest DIGIT 
    |
    ;
%%

void yyerror(char* s){ printf("invalid variable: %s\n", s); }
int yylex(){
    int c=getchar();
    if(c==EOF)return 0;
    if(isalpha(c))return LETTER;
    if(isdigit(c))return DIGIT;
    if(c=='\n')return '\n';
    return c;
}
int main(){
    yyparse();
    return 0;
}