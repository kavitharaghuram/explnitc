%{
#include<stdio.h>
int yylex();
void yyerror(char *s);
%}
%token IF ELSE OTHER

%%
program: stmt '\n' {printf("Maximum nesting level: %d\n", $1); }
        ;
stmt: IF stmt {$$ = $2 + 1;}
    | IF stmt ELSE stmt {$$=($2>$4)? $2+1: $4+1;}
    | OTHER { $$ =0; }
    ;
%%

void yyerror(char* s){ printf("%s\n", s); }

int yylex(){
    int c= getchar();
    if(c==EOF)return 0;
    switch(c){
        case 'i': return IF;
        case 'e': return ELSE;
        case 'a': return OTHER;
        case '\n': return '\n';
        default: return yylex();
    }
}
int main(){
    yyparse();
    return 0;
}