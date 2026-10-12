%{
    #include<stdio.h>
%}
%option yylineno
%%
[0-9]+ {printf("Line %d: Number: %s\n", yylineno, yytext);}
[a-zA-Z]+ {printf("lineL %d: word=%s\n", yylineno, yytext);}
[ \t]+ {}
\n {}
. {printf("line: %d symbol: %s\n", yylineno, yytext);}
%%
int yywrap(){return 1;}
int main(){
    yylex();
}