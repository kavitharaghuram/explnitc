%{
#include<stdio.h>
#include<stdlib.h>
#include<string.h>

int yylex();
int yyparse();
void yyerror(char* s);

#include "expr_tree.h"
struct tnode* root;
FILE* target_file;
void prefix(struct tnode *);
void postfix(struct tnode *);
int getReg();
void freeReg();
int codeGen(struct tnode *t);
void writeHeader();
void writeOutput();
void writeExit();
%}

%union{
    struct tnode *node;
}

%token <node> NUM
%type <node> expr start
%left '+' '-'
%left '*' '/'

%%
start : expr '\n' { root=$1; }
        ;
expr: expr '+' expr  {$$= makeOperatorNode('+', $1, $3); }
    | expr '-' expr  {$$= makeOperatorNode('-', $1, $3); }
    | expr '*' expr  {$$= makeOperatorNode('*', $1, $3); }
    | expr '/' expr  {$$= makeOperatorNode('/', $1, $3); }
    | '(' expr ')' { $$= $2; }
    | NUM {$$= $1; }
    ;
%%
struct tnode *makeLeafNode(int n){
    struct tnode* temp=(struct tnode*)malloc(sizeof(struct tnode));
    temp->val=n;
    temp->op=NULL;
    temp->left=NULL;
    temp->right=NULL;
    return temp;
}

struct tnode* makeOperatorNode(char op, struct tnode* l, struct tnode* r){
    struct tnode* temp=(struct tnode*)malloc(sizeof(struct tnode));
    temp->val=0;
    temp->op=(char*) malloc(2);
    temp->op[0]=op;
    temp->op[1]='\0';
    temp->left=l;
    temp->right=r;
    return temp;
}

void prefix(struct tnode* t){
    if(t==NULL)return;
    if(t->op==NULL)printf("%d ", t->val);
    else printf("%s ", t->op);
    prefix(t->left);
    prefix(t->right);
}
void postfix(struct tnode* t){
    if(t==NULL)return;
    postfix(t->left);
    postfix(t->right);
    if(t->op==NULL)printf("%d ", t->val);
    else printf("%s ", t->op);
}

//register management

int reg=-1;
int getReg(){
    return ++reg;
}

void freeReg(){
    reg--;
}

//code gen

int codeGen(struct tnode* t){
    if(t==NULL)return -1;
    if(t->op==NULL){
        int r=getReg();
        fprintf(target_file, "MOV R%d, %d\n", r, t->val);
        return r;
    }
    int left=codeGen(t->left);
    int right=codeGen(t->right);
    switch(t->op[0]){
        case '+': 
            fprintf(target_file, "ADD R%d, R%d\n", left, right);
            break;
        case '-':
            fprintf(target_file, "SUB R%d, R%d\n", left, right);
            break;
        case '*':
            fprintf(target_file, "MUL R%d, R%d\n", left, right);
            break;
        case '/':
            fprintf(target_file, "DIV R%d, R%d\n", left, right);
            break;
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
    fprintf(target_file,"BRKP\n");
    fprintf(target_file,"MOV SP, 4098\n");
}

void writeOutput(){
    fprintf(target_file, "MOV R0, [4096]\n");

    fprintf(target_file, "MOV R1, \"Write\"\n");
    fprintf(target_file, "PUSH R1\n");

    fprintf(target_file,"MOV R1, -2\n");
    fprintf(target_file,"PUSH R1\n");

    fprintf(target_file,"PUSH R0\n");

    fprintf(target_file, "MOV R1, 0\n");
    fprintf(target_file, "PUSH R1\n"); //dummy
    fprintf(target_file, "PUSH R1\n"); //for return value

    fprintf(target_file, "CALL 0\n"); //call library

    fprintf(target_file, "POP R1\n");
    fprintf(target_file, "POP R1\n");
    fprintf(target_file, "POP R1\n");
    fprintf(target_file, "POP R1\n");
    fprintf(target_file, "POP R1\n"); //restore stack
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
    printf("Prefix: ");
    prefix(root);
    printf("\n");

    printf("Postfix: ");
    postfix(root);
    printf("\n");
    target_file=fopen("output.xsm", "w");

    if(!target_file){
        printf("error opening file\n");
        return 1;
    }
    writeHeader();
    int result=codeGen(root);
    fprintf(target_file, "MOV [4096], R%d\n", result);
    freeReg();
    writeOutput();
    writeExit();
    fclose(target_file);
    return 0;
}