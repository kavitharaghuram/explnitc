%{
#include "y.tab.h"
%}

%%
[a-zA-Z] {yylval.c=yytext[0]; return LETTER;}
[+*()] {return *yytext;}
[\n] {return '\n'; }
[ \t] {}
. {}
%%

int yywrap(){return 1;}