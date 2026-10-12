%{
#include<stdio.h>
int yylex();
void yyerror(char* s);
%}
%left '+' '-'
%left '*' '/'
%token ID
%%
start: expr '\n';
expr: expr '+' expr {printf("+");}
    | expr '-' expr { printf("-");}
    | expr '*' expr { printf("*");}
    | expr '/' expr { printf("/");}
    | '(' expr ')'
    | ID {printf("%c", $1);}
    ;

%%
void yyerror(char* s){
    printf("%s\n", s);
}
int yylex(){
    int c;
    while((c=getchar())==' ' || c=='\t');
    if ((c>='a' && c<='z') || (c>='A' && c<='Z')){
        yylval=c;
        return ID;
    };
    return c;
}
int main(){
    yyparse();
}