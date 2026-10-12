%{
#include<stdio.h>
#include<string.h>

int yylex();
void yyerror(char *s);
%}

%union {
    char str[100];
}

%token <str> ID
%type <str> expr

%left '+' '-'
%left '*' '/'

%%

start:
    expr '\n' { printf("%s\n", $1); }
    ;

expr:
      expr '+' expr {
          sprintf($$.str, "+%s%s", $1.str, $3.str);
      }
    | expr '-' expr {
          sprintf($$.str, "-%s%s", $1.str, $3.str);
      }
    | expr '*' expr {
          sprintf($$.str, "*%s%s", $1.str, $3.str);
      }
    | expr '/' expr {
          sprintf($$.str, "/%s%s", $1.str, $3.str);
      }
    | '(' expr ')' {
          strcpy($$.str, $2.str);
      }
    | ID {
          strcpy($$.str, $1.str);
      }
    ;

%%

void yyerror(char *s) {
    printf("Invalid expression\n");
}

int yylex() {
    int c;

    while((c=getchar())==' ' || c=='\t');

    if((c>='a' && c<='z') || (c>='A' && c<='Z')) {
        yylval.str[0] = c;
        yylval.str[1] = '\0';
        return ID;
    }

    return c;
}

int main() {
    yyparse();
}