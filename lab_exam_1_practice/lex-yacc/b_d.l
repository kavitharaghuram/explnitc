%{
#include<stdio.h>
#include "y.tab.h"
%}
%%  
0 {yylval=0; return B;}
1 {yylval=1; return B;}
\n return '\n';
[ \t] ;
. return yytext[0];
%%
int yywrap(){return 1;}