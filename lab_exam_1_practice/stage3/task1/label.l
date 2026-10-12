%{
#include<stdio.h>
#include<stdlib.h>
#include<string,h>
#define MAX_LABELS 1000
typedef struct {
    char* name[64];
    int addr;
}Label;
Label table[MAX_LABELS];
int address=2056;
int pass=1;
int headerCount=0;
labelCount=0;
FILE* fout;
void addLabel(char* name, int addr){
    strcpy(table[labelCount].name,name);
    table[labelCount].addr=addr;
    labelCount++;
}
int lookupLabel(char* name){
    for(int i=0; i<labelCount; i++){
        if(strcmp(table[i].name, name)==0)return table[i].addr;
    }
    fprintf(stderr, "Error: undefined label%s\n", yytext);
    exit(1);
}
%}
LETTER [A-Za-z_]
DIGIT [0-9]
ID {LETTER}({LETTER}|{DIGIT})*
%%
^{ID}":"[ \t]*\n {
    char name[64];
    sscanf(yytext, "%[^:]", name);
    if(pass==1)addLabel(name, address);
}
^"JMP"[ \t]+{ID}[ \t]*\n{
    if(pass==1)address+=2;
    else{
        char label[64];
        sscanf(yytext, "%[^ \t\n]", label);
        fprintf(fout, "JMP %d\n", lookupLabel(label));
        address+=2;
    }
}
^"JZ"[\t]+"R"{DIGIT}+","[\t]*{ID}[ \t]*\n{
    if(pass==1)address+=2;
    else{
        char label[64];
        int reg;
        sscanf(yytext, "JZ R%d, %[^ \t\n]", &reg, label);
        fprintf(fout, "JZ R%d, %d\n", reg, lookupLabel(label));
        address+=2;
    }
}
^"JNZ"[ \t]+"R"{DIGIT}+","[ \t]*{ID}[ \t]*\n {
    if (pass == 1) {
        address += 2;
    } else {
        int reg;
        char label[64];
        sscanf(yytext, "JNZ R%d, %[^ \t\n]", &reg, label);
        fprintf(fout, "JNZ R%d, %d\n", reg, lookupLabel(label));
        address += 2;
    }
}

^"CALL"[ \t]+{ID}[ \t]*\n {
    if (pass == 1) {
        address += 2;
    } else {
        char label[64];
        sscanf(yytext, "CALL %[^ \t\n]", label);
        fprintf(fout, "CALL %d\n", lookupLabel(label));
        address += 2;
    }
}
^.*\n {
    if(headerCount<8){
        headerCount++;
        if(pass==2)fprintf(fout, "%s", yytext);
    }
    else {
        if(pass==1)address+=2;
        else {
            fprintf(fout, "%s", yytext);
            address+=2;
        }
    }
}
%%
int wwrap(){return 1;}
int main(int argc char** argv[]){
    yyin=fopen(argv[1], "r");
    pass=1;
    address=2056;
    headerCount=0;
    yylex();
    fclose(yyin);

    yyin=fopen(argv[1], "r");
    fout=fopen(argv[2], "w);
    pass=2;
    address=2056;
    headerCount=0;
    yyrestart(yyin);
    yylex();
    fclose(yyin);
    fclose(fout);
}