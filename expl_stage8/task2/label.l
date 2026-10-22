%{
#include<stdio.h>
#include<stdlib.h>
#include<string.h>
#define MAX_LABELS 1000
int baseAddr = 2056;
int headerLines = 8;
typedef struct{
    char name[64];
    int addr;
} Label;

Label table[MAX_LABELS];
int labelCount=0;

int address = 2056;
int pass=1;
int headerCount=0;
FILE* fout;

void addLabel(char* name, int addr){
    strcpy(table[labelCount].name, name);
    table[labelCount].addr=addr;
    labelCount++;
}
int lookupLabel(char *name){
    for(int i=0; i<labelCount; i++) if(strcmp(table[i].name, name)==0)return table[i].addr;
    fprintf(stderr, "Error: undefined label %s\n", name);
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
^"JMP"[ \t]+{ID}[ \t]*\n {
    if(pass==1)address+=2;
    else {
        char label[64];
        sscanf(yytext, "JMP %[^ \t\n]", label);
        fprintf(fout, "JMP %d\n", lookupLabel(label));
        address += 2;
    }
}
^"JZ"[ \t]+"R"{DIGIT}+","[ \t]*{ID}[ \t]*\n {
    if (pass == 1) {
        address += 2;
    } else {
        int reg;
        char label[64];
        sscanf(yytext, "JZ R%d, %[^ \t\n]", &reg, label);
        fprintf(fout, "JZ R%d, %d\n", reg, lookupLabel(label));
        address += 2;
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
^"CALL"[ \t]+"R"{DIGIT}+[ \t]*\n {
    address += 2;
    if (pass == 2) fprintf(fout, "%s", yytext);
}
^"MOV"[ \t]+"R"{DIGIT}+","[ \t]*"F"{DIGIT}+[ \t]*\n {
    if (pass == 1) {
        address += 2;
    } else {
        int reg;
        char label[64];
        sscanf(yytext, "MOV R%d, %[^ \t\n]", &reg, label);
        fprintf(fout, "MOV R%d, %d\n", reg, lookupLabel(label));
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
    if (headerCount < headerLines) {
        headerCount++;
        if (pass == 2) fprintf(fout, "%s", yytext);
        
    } else {
        if (pass == 1) {
            address += 2;
        } else {
            fprintf(fout, "%s", yytext);
            address += 2;
        }
    }
}

%%

int yywrap(){ return 1; }

int main(int argc, char** argv){
    if (argc < 3) {
        printf("Usage: %s <input> <output> [baseAddr=2056] [headerLines=8]\n", argv[0]);
        return 1;
    }
    if (argc > 3) baseAddr = atoi(argv[3]);
    if (argc > 4) headerLines = atoi(argv[4]);

    /* Pass 1 */
    yyin = fopen(argv[1], "r");
    if (!yyin) { perror("fopen"); return 1; }
    pass = 1;
    address = baseAddr;          /* was 2056 */
    headerCount = 0;
    yylex();
    fclose(yyin);

    /* Pass 2 */
    yyin = fopen(argv[1], "r");
    fout = fopen(argv[2], "w");
    if (!yyin || !fout) { perror("fopen"); return 1; }
    pass = 2;
    address = baseAddr;          /* was 2056 */
    headerCount = 0;
    yyrestart(yyin);
    yylex();
    fclose(yyin);
    fclose(fout);

    printf("Label translation complete. Output written to %s\n", argv[2]);
    return 0;
}