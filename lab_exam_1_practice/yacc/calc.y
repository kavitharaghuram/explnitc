%{
#include<stdio.h>
#include<math.h>
int yylex();
void yyerror(char* s);
int values[26];
int error=0;
%}
%left '+' '-'
%left '*' '/' '%'
%right UMINUS
%right '^'
%token NUMBER
%token ID
%%
start: start expr '\n' {if(error==1){printf("error");}else printf("valid expr: result=%d\n", $2); error=0;}
    | start ID '=' expr ';' '\n'{
        values[$2-'a']=$4;
    }
    |
    ;
expr:
    expr '+' expr { $$=$1+$3;}
    | expr '-' expr { $$=$1-$3;}
    | expr '*' expr { $$=$1*$3;}
    | expr '/' expr {
        if ($3==0){
            printf("Division By zero not supported");
            error=1;
            $$=0;
        }
        else {
            $$=$1/$3;
        }
    }
    | expr '%' expr { $$=$1%$3;}
    | '(' expr ')' { $$=$2;}
    | '-' expr %prec UMINUS {$$= -$2;}
    | expr '^' expr {$$= (int)pow($1, $3);}
    | NUMBER { $$=$1;}
    | ID {$$=values[$1-'a'];}
    ;
    
%%
void yyerror(char* s){
    printf("invalid expr\n");
}
int yylex(){
    int c;
    int num=0;
    while ((c=getchar())==' '|| c=='\t');
    if (c>='0' && c<='9'){
        do {
            num=num*10+(c-'0');
            c=getchar();
        } while(c>='0' && c<='9');
        yylval=num;
        ungetc(c, stdin);
        return NUMBER;
    }
    if(c>='a' && c<='z'){
        yylval=c;
        return ID;
    }
    return c;
}
int main(){
    yyparse();
}