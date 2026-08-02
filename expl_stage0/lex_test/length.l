%{
#include <stdio.h>
int length=0;
%}
%%
[0-9]+ {length+=yyleng;}
%%
int yywrap(){ return 1; }
int main(){
    yylex();
    printf("%d\n", length);
    return 0;
}