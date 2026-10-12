%{
#include<stdio.h>
int yylex();
void yyerror(char* s);
int operators=0;
int operands=0;    
%}
%token ID
%left '+' '-'
%left '*' '/'

%%

start :
    expr '\n' {
        printf("Operators=%d\n", operators);
        printf("operands=%d\n", operands);
    }
    ;
expr:
    expr '+' expr {operators++;}
    | expr '-' expr {operators++;}
    | expr '*' expr {operators++;}
    | expr '/' expr {operators++;}
    | '(' expr ')'
    | ID {operands++;}
    ;
%%

void yyerror(char* s){
    printf("invalid expr");
}
int yylex(){
    int c;
    while((c=getchar())==' '|| c=='\t');
    if((c>='a' && c<='z') || (c>='A' && c<='Z')){
        yylval=c;
        return ID;
    }
    return c;
}
int main(){
    yyparse();
}
