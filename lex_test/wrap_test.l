%{
#include <stdio.h>
%}
%%
[0-9]+  printf("number ");
\n      ;
.       ;
%%

int first_pass = 1;

int yywrap()
{
    if (first_pass)
    {
        first_pass = 0;
        yyin = fopen("input_file.l", "r");
        if (!yyin) return 1;
        return 0;
    }
    return 1;
}

int main()
{
    yyin = stdin;
    yylex();
    printf("\n");
    return 1;
}