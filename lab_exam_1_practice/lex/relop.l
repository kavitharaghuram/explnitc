%{
    #include<stdio.h>
%}

%%
"<=" {printf("LE\n");}
"<" {printf("LT\n");}
">=" {printf("GE\n");}
">" {printf("GT\n");}
"==" {printf("EQ\n");}
"!=" {printf("NE\n");}
%%

int yywrap(){
    return 1;
}
int main(){
    yylex();
}