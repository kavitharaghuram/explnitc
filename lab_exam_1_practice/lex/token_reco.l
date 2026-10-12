%{
    #include<stdio.h>
%}
op [+-/*]
dig [0-9]+
id [A-Za-z_][A-Za-z0-9_]*
ws [ \t\n]+
%%
"int" { printf("int\n" );}
"if" { printf("if\n" );}
"while" { printf("while\n" );}
"return" { printf("return\n" );}
"int" { printf("int\n" );}
{op} {printf("operator\n"); }
{dig} {printf("dig\n"); }
{id} { printf("id\n"); }
{ws} { }
. {printf("unknown: %s\n", yytext);}

%%
int yywrap(){ return 1;}
int main(){
    yylex();
}