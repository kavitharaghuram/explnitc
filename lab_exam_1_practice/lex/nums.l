%{
    #include<stdio.h>
%}
%%
0[xX][0-9a-fA-F]+ {printf("hexadecimal\n"); }
0[bB][01]+ {printf("binary\n");}
0[0-7]+ {printf("octal\n");}
[0-9]+ {printf("decimal\n");}

.|\n {}
%%
int yywrap(){return 1;}
int main(){
    yylex();
}