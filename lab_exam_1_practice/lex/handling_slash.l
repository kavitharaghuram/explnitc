%{
#include<stdio.h>
%}
%%
\"([^\"\\]|\\.)*\" {printf("string: %s\n", yytext);}
.|\n {}
%%
int yywrap(){ return 1;}
int main(){
    yylex();
}