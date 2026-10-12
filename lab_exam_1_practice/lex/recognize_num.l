%{
#include<stdio.h>
%}
digit [0-9]
%%
{digit}+ {printf("integer: %s\n", yytext);}
{digit}+\.{digit}+ {printf("float: %s\n", yytext);}
[ \t\n] { }
. { printf("unknown %s\n", yytext);}
%%

int yywrap(){ return 1;}
int main(int argc, char* argv[]){
    yylex();
    return 0;
}