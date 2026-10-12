%{
    #include<stdio.h>
%}
%%
"hello" {printf("HELLO");}
. {printf("%s", yytext);}
%%
int yywrap(){ return 1;}
int main(){
    yylex();
}