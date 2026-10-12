%{
#include<stdio.h>
#include<stdlib.h>
#include<ctype.h>
#include<string.h>
#include "y.tab.h"
#include "expl.h"

%}
%%
[0-9]+ {yylval.node=makeLeafNode(atoi(yytext));
    return NUM; }
[+-=/*()] {return *yytext;}
[ \t] {}
[\n] { return '\n';}
. {printf("invalid character %s", yytext);}

%%
int yywrap(){
    return 1;
}
