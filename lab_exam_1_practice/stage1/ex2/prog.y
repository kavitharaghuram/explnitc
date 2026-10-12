%{
#include<stdio.h>
#include<stdlib.h>
#include<string.h>
#include "y.tab.h"
#include "expl.h"

int yylex();
void yyerror(char* s);

tnode* root=NULL;
FILE* target_file;
tnode* makeLeafNode(int n);
tnode* makeOperatorNode(char op, tnode* left, tnode* right);
void prefix(tnode* t);
void postfix(tnode* t);

int getReg();
void freeReg();
int codeGen(tnode* t);
void writeHeader();
void writeExit();
void writeOutput();
%}
%union{
    struct tnode* node;
}
%token<node>NUM
%type<node>start
%type<node>expr
%left '+' '-'
%left '*' '/'
%%
start: expr '\n' {
    root=$1;
    }
    ;
expr: '+' expr expr {$$=makeOperatorNode('+', $2, $3);}
    | '-' expr expr {$$=makeOperatorNode('-', $2, $3);}
    | '*' expr expr {$$=makeOperatorNode('*', $2, $3);}
    | '/' expr expr {$$=makeOperatorNode('/', $2, $3);}
    | '(' expr ')' {$$=$2;}
    | NUM {$$=$1;}
    ;
%%
tnode* makeLeafNode(int n){
    tnode* temp=(tnode*)malloc(sizeof(tnode));
    temp->op=NULL;
    temp->val=n;
    temp->left=NULL;
    temp->right=NULL;
    return temp;
}
tnode* makeOperatorNode(char op, tnode* l, tnode* r){
    tnode* temp=(tnode*)malloc(sizeof(tnode));
    temp->op=(char*)malloc(2);
    temp->op[0]=op;
    temp->op[1]='\0';
    temp->val=0;
    temp->left=l;
    temp->right=r;
    return temp;
}
void prefix(tnode* t){
    if(t==NULL)return;
    if(t->op==NULL){
        printf("%d ", t->val);
    }
    else printf("%c ", t->op[0]);
    prefix(t->left);
    prefix(t->right);
}
void postfix(tnode* t){
    if(t==NULL)return;
    postfix(t->left);
    postfix(t->right);
    if(t->op==NULL){
        printf("%d ", t->val);
    }
    else printf("%c ", t->op[0]);
}
int reg=-1;
int getReg(){
    return ++reg;
}
void freeReg(){
    reg--;
}
void yyerror(char* s){
    printf("%s", s);
}
int codeGen(tnode* t){
    if(!t)return -1;
    if(!t->op){
        int r=getReg();
        fprintf(target_file, "MOV R%d, %d\n", r, t->val);
        return r;
    }
    int left=codeGen(t->left);
    int right=codeGen(t->right);
    switch(t->op[0]){
        case '+' :
            {
                fprintf(target_file, "ADD R%d, R%d\n", left, right);
                break;
            }
        case '-' :
            {
                fprintf(target_file, "SUB R%d, R%d\n", left, right);
                break;
            }
        case '*' :
            {
                fprintf(target_file, "MUL R%d, R%d\n", left, right);
                break;
            }
        case '/' :
            {
                fprintf(target_file, "DIV R%d, R%d\n", left, right);
                break;
            }
    }
    freeReg();
    return left;
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
    fprintf(target_file, "MOV SP, 4098\n");
}
void writeOutput(){
    fprintf(target_file, "MOV R0, [4096]\n");
    fprintf(target_file, "MOV R1, \"Write\"\n");
    fprintf(target_file, "PUSH R1\n");
    fprintf(target_file, "MOV R1, -2\n");
    fprintf(target_file, "PUSH R1\n");
    fprintf(target_file, "PUSH R0\n");
    fprintf(target_file, "MOV R1, 0\n");
    fprintf(target_file, "PUSH R1\n");
    fprintf(target_file, "PUSH R1\n");
    fprintf(target_file, "CALL 0\n");
    fprintf(target_file, "POP R1\n");
    fprintf(target_file, "POP R1\n");
    fprintf(target_file, "POP R1\n");
    fprintf(target_file, "POP R1\n");
    fprintf(target_file, "POP R1\n");
}
void writeExit(){
    fprintf(target_file, "MOV R0, 0\n");
    fprintf(target_file, "MOV R1, \"Exit\"\n");
    fprintf(target_file, "PUSH R1\n");
    fprintf(target_file, "PUSH R0\n");
    fprintf(target_file, "PUSH R0\n");
    fprintf(target_file, "PUSH R0\n");
    fprintf(target_file, "PUSH R0\n");
    fprintf(target_file, "PUSH R0\n");
    fprintf(target_file, "CALL 0\n");
}
int main(){
    yyparse();
    printf("Prefix: ");
    prefix(root);
    printf("\n");
    printf("Postfix: ");
    postfix(root);
    printf("\n");

    target_file=fopen("output.xsm", "w");
    writeHeader();
    int result=codeGen(root);
    fprintf(target_file, "MOV [4096], R%d\n", result);
    freeReg();
    writeOutput();
    writeExit();
    fclose(target_file);
}