%{
    #include "expl.h"
    #include "y.tab.h"
%}
%%
"begin" {return BEGIN_; }
"end" {return END; }
"read" {return READ; }
"write" {return WRITE; }
[0-9]+ {yylval.node= createTree(atoi(yytext), TYPE_INT, NULL, NODE_NUM, NULL, NULL); 
    return NUM;
    }
[a-z] {yylval.node=createTree(0, TYPE_INT, strdup(yytext), NODE_ID, NULL, NULL);
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