%{
    #include<stdio.h>
%}
digit [0-9]
letter [A-Za-z]

%%
({letter}|_)({letter}|{digit}|_)* {printf("IDENTIFER %s\n", yytext);}
{digit}+{letter}({letter}|{digit}|_)* {printf("INVALID %s\n", yytext);}
{digit}+ {printf("NUMBER %s\n", yytext); }
[ \t\n] { }
. {printf("UNKNOWN %s\n", yytext); }

%%
int yywrap(){ return 1;}
int main(){
    yylex();

}