%{
#include<stdio.h>
#include<ctype.h>
%}
%%
[Aa][a-zA-Z][a-zA-Z] {
    int i;
    for(i=0; i<yyleng; i++)
        putchar(toupper(yytext[i]));
    printf("\n");
}
. ;
\n ;
%%

int yywrap(){ return 1; }
int main(int argc, char* argv[]){
    if(argc>1){
        FILE* fp= fopen(argv[1], "r");
        if(fp)yyin=fp;
    }
    yylex();
    return 0;
}