%{
    #include<stdio.h>
%}
vowel [aeiou]
cons [bcdfghjklmnpqrstvwxyz]
%%
{vowel} { printf("vow ");}
{cons} { printf("cons "); }

%%
int yywrap(){ return 1;}
int main(){
    yylex();
    return 0;
}