%{
    #include<stdio.h>
%}
%%
"//".* {}
"/*"([^*]|\*+[^*/])*\*+"/" {}
.|\n {printf("%s", yytext);}
%%
int yywrap(){ return 1;}
int main(){
    yylex();
}