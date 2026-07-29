%{
#include "y.tab.h"
#include<stdio.h>
#include<stdlib.h>
#include<string.h>
%}

%%
[a-zA-Z]+ {yylval.c=strdup(yytext); return WORD; }
[+*()] {return *yytext;}
[\n] {return '\n';}
[ \t] {}
. {}
%%
int yywrap(){return 1;}