%{
    #include<stdio.h>
    int yylex();
    void yyerror(char* s);
%}
%%
start: S '\n' {printf("valid\n");}
    ;
S: 'a' S 'b'
    | 'a' A
    ;
A: 'a' A
    | 
    ;
%%
void yyerror(char* s){
   printf("%s", s);
}
int yylex(){
    int c;
    while ((c=getchar())==' ' || c=='\t');
    return c;
}
int main(){
    yyparse();
}