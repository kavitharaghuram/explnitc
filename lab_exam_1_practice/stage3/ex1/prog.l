%{
#include<stdio.h>
#include<stdlib.h>
#include<string.h>
#include<ctype.h>
#include "y.tab.h"
#include "expl.h"
%}
%%
"begin" {return BEGIN_;}
"end" {return END;}
"if" {return IF;}
"while" {return WHILE;}
"endif" {return ENDIF;}
"endwhile" {return ENDWHILE;}
"then" {return THEN;}
"read" {return READ;}
"write" {return WRITE;}
"do" {return DO;}
"else" {return ELSE;}
"<=" {return LE;}
">=" {return GE;}
"<" {return LT;}
">" {return GT;}
"==" {return EQ;}
"!=" {return NE;}
[0-9]+ {yylval.node=createTree(atoi(yytext), TYPE_INT, NULL, NODE_NUM, NULL, NULL, NULL);
    return NUM;}
[a-z] {yylval.node=createTree(0, TYPE_INT, strdup(yytext), NODE_ID, NULL, NULL, NULL);
    return ID;}
[+-/*();=] {return *yytext;}
[ \t\r\n] {}
. {printf("invalid\n");}
%%
int yywrap(){return 1;}

