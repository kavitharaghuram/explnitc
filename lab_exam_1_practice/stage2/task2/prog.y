%{
#include<stdio.h>
#include<stdlib.h>
#include<string.h>
#include "y.tab.h"
#include "expl.h"
int yylex();
void yyerror(char* s);
FILE* target_file;
tnode* createTree(int val, int type, char* varname, int nodetype, tnode* l, tnode* r);
tnode* root;
int reg=-1;
int getReg();
void freeReg();
int getAddress(char* varname);
int codeGen(tnode* t);
void writeHeader();
void writeExit();
%}
%union{
    struct tnode* node;
}
%token BEGIN_ END READ WRITE
%token <node> NUM ID
%type <node> Program Slist Stmt InputStmt OutputStmt AsgStmt E
%left '+' '-'
%left '*' '/'
%%
Program : BEGIN_ Slist END {root=$2;}
    | BEGIN_ END {root=NULL;}
    ;
Slist: Slist Stmt {$$=createTree(0, TYPE_INT, NULL, NODE_CONNECT, $1, $2);}
    | Stmt {$$ =$1;};
Stmt: InputStmt {$$=$1;}
    | OutputStmt {$$=$1;}
    | AsgStmt {$$=$1;};
InputStmt: READ '(' ID ')' ';' {$$=createTree(0, TYPE_INT, NULL, NODE_READ, $3, NULL);}
    ;
OutputStmt: WRITE '(' E ')' ';' {$$=createTree(0, TYPE_INT, NULL, NODE_WRITE, $3, NULL);}
    ;
AsgStmt: ID '=' E ';' {$$=createTree(0, TYPE_INT, NULL, NODE_ASSIGN, $1, $3);}
    ;
E: E '+' E {$$=createTree(0, TYPE_INT, NULL, NODE_PLUS, $1, $3);}
    | E '*' E {$$=createTree(0, TYPE_INT, NULL, NODE_MUL, $1, $3);}
    | E '-' E {$$=createTree(0, TYPE_INT, NULL, NODE_MINUS, $1, $3);}
    | E '/' E {$$=createTree(0, TYPE_INT, NULL, NODE_DIV, $1, $3);}
    | '(' E ')' {$$=$2;}
    | NUM {$$=$1;}
    | ID {$$=$1;}
    ;
%%
tnode* createTree(int val, int type, char* varname, int nodetype, tnode* l, tnode* r){
    tnode* temp=(tnode*)malloc(sizeof(tnode));
    temp->val=val;
    temp->type=type;
    temp->varname=varname;
    temp->nodetype=nodetype;
    temp->left=l;
    temp->right=r;
    return temp;
}
void printTree(tnode* t){
    if(!t)return;
    switch(t->nodetype){
        case NODE_ID: {
            printf("ID (%s)\n", t->varname);
            break;
        }
        case NODE_NUM: {
            printf("NUM (%d)\n", t->val);
            break;
        }
        case NODE_PLUS: {
            printf("+\n");
            break;
        }
        case NODE_MINUS: {
            printf("-\n");
            break;
        }
        case NODE_MUL: {
            printf("*\n");
            break;
        }
        case NODE_DIV: {
            printf("/\n");
            break;
        }
        case NODE_READ: {
            printf("READ\n");
            break;
        }
        case NODE_WRITE: {
            printf("WRITE\n");
            break;
        }
        case NODE_CONNECT: {
            printf("CONNECT\n");
            break;
        }
        case NODE_ASSIGN: {
            printf("ASSIGN\n");
            break;
        }
        default: printf("unknown\n");
    }
    printTree(t->left);
    printTree(t->right);
}

int getReg(){return ++reg;}
void freeReg(){reg--;}
int getAddress(char* varname){
    return 4096+(varname[0]-'a');
}
int codeGen(tnode* t){
    if(!t)return -1;
    if(t->nodetype==NODE_NUM){
        int r=getReg();
        fprintf(target_file, "MOV R%d, %d\n", r, t->val);
        return r;
    }
    if(t->nodetype==NODE_ID){
        int r=getReg();
        fprintf(target_file, "MOV R%d, [%d]\n", r, getAddress(t->varname));
        return r;
    }
    if(t->nodetype==NODE_PLUS || t->nodetype==NODE_MINUS || t->nodetype==NODE_MUL || t->nodetype==NODE_DIV){
        int l=codeGen(t->left);
        int r=codeGen(t->right);
        switch(t->nodetype){
            case NODE_PLUS:{
                fprintf(target_file, "ADD R%d, R%d\n", l, r);
                break;
            }
            case NODE_MINUS:{
                fprintf(target_file, "SUB R%d, R%d\n", l, r);
                break;
            }
            case NODE_MUL:{
                fprintf(target_file, "MUL R%d, R%d\n", l, r);
                break;
            }
            case NODE_DIV:{
                fprintf(target_file, "DIV R%d, R%d\n", l, r);
                break;
            }

        }
        freeReg();
        return l;
    }
    if(t->nodetype==NODE_READ){
        int addr=getAddress(t->left->varname);
        fprintf(target_file, "MOV R0, \"Read\"\n");
        fprintf(target_file, "PUSH R0\n");
        fprintf(target_file, "MOV R0, -1\n");
        fprintf(target_file, "PUSH R0\n");
        fprintf(target_file, "MOV R0, %d\n", addr);
        fprintf(target_file, "PUSH R0\n");
        fprintf(target_file, "MOV R0, 0\n");
        fprintf(target_file, "PUSH R0\n");
        fprintf(target_file, "PUSH R0\n");
        fprintf(target_file, "CALL 0\n");
        fprintf(target_file, "POP R0\n");
        fprintf(target_file, "POP R0\n");
        fprintf(target_file, "POP R0\n");
        fprintf(target_file, "POP R0\n");
        fprintf(target_file, "POP R0\n");
        return -1;
    }
    if(t->nodetype==NODE_WRITE){
        int r=codeGen(t->left);
        fprintf(target_file, "MOV R1, \"Write\"\n");
        fprintf(target_file, "PUSH R1\n");
        fprintf(target_file, "MOV R1, -2\n");
        fprintf(target_file, "PUSH R1\n");
        fprintf(target_file, "PUSH R%d\n", r);
        fprintf(target_file, "MOV R1, 0\n");
        fprintf(target_file, "PUSH R1\n");
        fprintf(target_file, "PUSH R1\n");
        fprintf(target_file, "CALL 0\n");
        fprintf(target_file, "POP R1\n");
        fprintf(target_file, "POP R1\n");
        fprintf(target_file, "POP R1\n");
        fprintf(target_file, "POP R1\n");
        fprintf(target_file, "POP R1\n");
        freeReg();
        return -1;
    }
    if(t->nodetype==NODE_ASSIGN){
        int r=codeGen(t->right);
        int addr=getAddress(t->left->varname);
        fprintf(target_file, "MOV [%d], R%d\n", addr, r);
        freeReg();
        return -1;
    }
    if(t->nodetype==NODE_CONNECT){
        codeGen(t->left);
        codeGen(t->right);
        return -1;
    }
    return -1;
}
void writeHeader(){
    fprintf(target_file, "0\n");
    fprintf(target_file, "2056\n");
    fprintf(target_file, "0\n");
    fprintf(target_file, "0\n");
    fprintf(target_file, "0\n");
    fprintf(target_file, "0\n");
    fprintf(target_file, "0\n");
    fprintf(target_file, "1\n");
    fprintf(target_file, "BRKP\n");
    fprintf(target_file, "MOV SP, 4122\n");
}
void writeExit(){
    fprintf(target_file, "MOV R0, 0\n");
    fprintf(target_file, "MOV R1, \"Exit\"\n");
    fprintf(target_file, "PUSH R1\n");
    fprintf(target_file, "PUSH R0\n");
    fprintf(target_file, "PUSH R0\n");
    fprintf(target_file, "PUSH R0\n");
    fprintf(target_file, "PUSH R0\n");
    fprintf(target_file, "CALL 0\n");
}
void yyerror(char* s){
    printf("%s\n", s);
}
int main(){
    yyparse();
    target_file=fopen("output.xsm", "w");
    writeHeader();
    int result=codeGen(root);
    writeExit();
    fclose(target_file);
    printTree(root);
    return 0;
}