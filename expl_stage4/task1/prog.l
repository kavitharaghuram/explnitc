%{
    #include "expl.h"
    #include "y.tab.h"
%}
%%
"begin" {return BEGIN_; }
"end" {return END; }
"read" {return READ; }
"write" {return WRITE; }
"if" {return IF;}
"then" {return THEN; }
"else" {return ELSE; }
"endif" {return ENDIF; }
"break" {return BREAK; }
"continue" {return CONTINUE; }
"while" {return WHILE; }
"do" {return DO; }
"repeat" {return REPEAT; }
"until"  {return UNTIL;  }
"endwhile" {return ENDWHILE; }
"decl" {return DECL; }
"enddecl" {return ENDDECL; }
"int" {return INT; }
"str" {return STR; }
"," {return ','; }

"<=" {return LE; }
">=" {return GE; }
"<" {return LT; }
">" {return GT; }
"==" {return EQ; }
"!=" {return NE; }

[0-9]+ {yylval.node= createTree(atoi(yytext), TYPE_INT, NULL, NODE_NUM, NULL, NULL, NULL); 
    return NUM;
    }
[a-z]+ {yylval.node=createTree(0, TYPE_INT, strdup(yytext), NODE_ID, NULL, NULL, NULL);
    return ID; 
    }
"+"            { return '+'; }
"-"            { return '-'; }
"*"            { return '*'; }
"/"            { return '/'; }
"="            { return '='; }

"("            { return '('; }
")"            { return ')'; }

";"            { return ';'; }

[ \t\r\n]+     ;

.              { printf("Invalid character: %s\n", yytext);}

%%
int yywrap(){
    return 1;
}