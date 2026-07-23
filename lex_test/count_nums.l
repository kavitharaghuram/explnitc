%{
#include<stdio.h>
int int_count=0, float_count=0;
%}
digit[0-9]

%%
{digit}+"."{digit}+ {float_count++;}
{digit}+ {int_count++;}
. ;
\n ;
%%

int yywrap(){return 1;}
int main(int argc, char* argv[]){
    if(argc>1){
        FILE* fp=fopen(argv[1], "r");
        if(fp){
            yyin=fp;
        }
    }
    yylex();
    printf("integers=%d\nfloats=%d\n", int_count, float_count);
    return 0;
}