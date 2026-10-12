%{
#include<stdio.h>
#include "y.tab.h"
#include "expl.h"
%}
%%
"begin" {return BEGIN_;}
"end" {return END;}
"read" {return READ;}
"write" {return WRITE;}
"if" {return IF;}
"then" {return THEN;}
"else" {return ELSE;}
"endif" {return ENDIF;}
"while" {return WHILE;}
"break" {return BREAK;}
"continue" {return CONTINUE;}
"do" {return DO;}
"<=" {return LE;}
">=" {return GE;}
">" {return GT;}
"<" {return LT;}
"==" {return EQ;}
"!=" {return NE;}

"endwhile" {return ENDWHILE;}
[0-9]+ {yylval.node=createTree(atoi(yytext), TYPE_INT, NULL, NODE_NUM, NULL, NULL, NULL);
    return NUM;}
[a-z] {yylval.node=createTree(0, TYPE_INT, strdup(yytext), NODE_ID, NULL, NULL, NULL);
    return ID;}
[+-/*()=;] {return *yytext;}
[ \t\r\n] {}
. {printf("invalid %s\n", yytext);}

%%
int yywrap(){return 1;}
