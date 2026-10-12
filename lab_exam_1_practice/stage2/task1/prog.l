%{
#include<stdio.h>
#include "expl.h"
#include "y.tab.h"
#include<stdlib.h>
#include<string.h>
%}
%%
"begin" {return BEGIN_ ;}
"end" {return END; }
"read" {return READ; }
"write" { return WRITE; }
[0-9]+ {yylval.node=createTree(atoi(yytext), TYPE_INT, NULL, NODE_NUM, NULL, NULL);
    return NUM;}
[a-z] {yylval.node=createTree(0, TYPE_INT, strdup(yytext), NODE_ID, NULL, NULL);
    return ID;
    }
[+-/*()=;] {return *yytext;}
[ \t\r\n]+     ;
. {printf("invalid %s\n", yytext);}
%%
int yywrap(){return 1;}