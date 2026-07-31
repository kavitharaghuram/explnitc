%{
#include<stdio.h>
#include<stdlib.h>
#include<string.h>
#include "y.tab.h"
#include "expr_tree.h"
%}

%%
[0-9]+ { yylval.node=makeLeafNode(atoi(yytext));
            return NUM;
        }
[+\-*/()] {return *yytext;}
[ \t] ;
[\n] {return '\n'; }
.       { printf("Invalid character: %s\n", yytext); }
%%

int yywrap(){
    return 1;
}