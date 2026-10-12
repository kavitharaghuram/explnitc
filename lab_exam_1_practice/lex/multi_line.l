%{
#include<stdio.h>
int depth=0;
%}
%x comment

%%
"/*" {
    depth=1;
    BEGIN(comment);}
<comment>"/*" {
    depth++;
}
<comment>"*/" { 
    depth--;
    if(depth==0)BEGIN(INITIAL);}
<comment>\n {}
<comment>. {}
.|\n {printf("%s", yytext);}
%%
int yywrap(){return 1;}
int main(){
    yylex();
}