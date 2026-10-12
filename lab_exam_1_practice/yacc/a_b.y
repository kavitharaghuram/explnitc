%{
#include<stdio.h>
int yylex();
void yyerror(char* s);
%}
%%
start: S '\n' {printf("valid\n");}
    ;
S: 'a' S 'b'
    | 'a' 'b'
    ;
%%
int yylex(){
    int c;
    while((c=getchar())==' ' || c=='\t');
    return c;
}
void yyerror(char* s){
    printf("%s\n", s);
}
int main(){
    yyparse();
}