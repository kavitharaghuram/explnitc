%{
#include<stdio.h>
int lines=0, words=0, chars=0;
%}

%%
\n {lines++; chars++;}
[^ \t\n]+ {words++; chars+= yyleng; }
. {chars++;}
%%

int yywrap(){return 1;}

int main(int argc, char* argv[]){
    if(argc>1){
        FILE* fp= fopen(argv[1], "r");
        if(fp)yyin=fp;
    }
    yylex();
    printf("lines= %d\nwords=%d\nchars=%d\n", lines, words, chars);
    return 0;
}