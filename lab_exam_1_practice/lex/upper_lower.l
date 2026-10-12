%{
#include<stdio.h>
#include<ctype.h>
#include<string.h>

%}
%x STRING

%%
\" {printf("\""); BEGIN(STRING);}
<STRING>\" {
    printf("\"");
    BEGIN(INITIAL);
}
<STRING>[a-z] {
    printf("%c", toupper(yytext[0]));
}
<STRING>[A-Z] {
    printf("%c", tolower(yytext[0]));
}
<STRING>. {
    printf("%s", yytext);
}
<STRING>\n {
    printf("%s", yytext);
}
.|\n {printf("%s", yytext); }
%%
int yywrap(){return 1;}
int main(){
    yylex();
}