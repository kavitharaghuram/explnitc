%{
#include<stdio.h>
int countInt=0, countChar=0, countFloat=0;
%}
%%
"int" {countInt++;}
"float" {countFloat++;}
"char" {countChar++;}
.|\n {}
%%
int yywrap(){return 1;}
int main(){
    yylex();
    printf("int = %d\n", countInt);
    printf("float = %d\n", countFloat);
    printf("char = %d\n", countChar);
}