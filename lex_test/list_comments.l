%{
#include<stdio.h>
%}

%%
"//".* {printf("%s\n", yytext);}
"/*"([^*]|"*"[^/])*"*/"  {printf("%s\n", yytext);}
. ;
\n ;
%%
int yywrap() { return 1; }

int main(int argc, char *argv[])
{
    if (argc > 1)
    {
        FILE *fp = fopen(argv[1], "r");
        if (fp) yyin = fp;
    }
    yylex();
    return 0;
}