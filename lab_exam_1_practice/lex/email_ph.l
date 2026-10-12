%{
#include<stdio.h>
%}
%%
[a-z0-9_]+"@gmail.com" {printf("Email: %s\n", yytext);}
"+91"[0-9]{10} {printf("Phone number : %s\n", yytext);}
%%
int yywrap(){return 1;}
int main(){
    yylex();
}