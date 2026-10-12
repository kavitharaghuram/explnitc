%{
#include<stdio.h>
#include<stdlib.h>
#include<string.h>
#include<ctype.h>
#include "y.tab.h"
#include "expl.h"
int yylex();
void yyerror(char* s);
int memory[26];
int getAddress(char* varname);
tnode* root=NULL;
int evaluate(tnode* root);
tnode* createTree(int val, int type, char* varname, int nodetype, tnode* left, tnode* middle, tnode* right);
extern FILE* yyin;
%}
%union{
    struct tnode* node;
}
%token <node> ID NUM
%token IF ELSE READ WRITE THEN WHILE DO ENDIF ENDWHILE BEGIN_ END
%token LT GT NE LE EQ GE 
%type <node> Program Slist Stmt InputStmt OutputStmt AsgStmt IfStmt WhileStmt E
%left LT GT LE GE EQ NE
%left '+' '-'
%left '/' '*'
%%
Program: BEGIN_ Slist END ';' {root=$2;}
        | BEGIN_ END ';' {root=NULL;}
        ;
Slist: Slist Stmt {$$=createTree(0, TYPE_NONE, NULL, NODE_CONNECT, $1, NULL, $2);}
    | Stmt {$$=$1;}
    ;
Stmt: InputStmt {$$=$1;}
    | OutputStmt {$$=$1;}
    | AsgStmt {$$=$1;}
    | IfStmt {$$=$1;}
    | WhileStmt {$$=$1;}
    ;
InputStmt: READ '(' ID ')' ';' {$$=createTree(0, TYPE_NONE, NULL, NODE_READ, $3, NULL, NULL);}
    ;
OutputStmt: WRITE '(' E ')' ';' {$$=createTree(0, TYPE_NONE, NULL, NODE_WRITE, $3, NULL, NULL);}
    ;
AsgStmt: ID '=' E ';' {$$=createTree(0, TYPE_NONE, NULL, NODE_ASSIGN, $1, NULL, $3);}
    ;
IfStmt: IF '(' E ')' THEN Slist ELSE Slist ENDIF ';' {$$=createTree(0, TYPE_NONE, NULL, NODE_IF, $3, $6, $8);}
    | IF '(' E ')' THEN Slist ENDIF ';' {$$=createTree(0, TYPE_NONE, NULL, NODE_IF, $3, $6, NULL);}
    ;
WhileStmt: WHILE '(' E ')' DO Slist ENDWHILE ';' {$$=createTree(0, TYPE_NONE, NULL, NODE_WHILE, $3, $6, NULL);}
    ;
E: E LT E {$$=createTree(0, TYPE_BOOL, NULL, NODE_LT, $1, NULL, $3);}
    | E LE E {$$=createTree(0, TYPE_BOOL, NULL, NODE_LE, $1, NULL, $3);}
    | E GT E {$$=createTree(0, TYPE_BOOL, NULL, NODE_GT, $1, NULL, $3);}
    | E GE E {$$=createTree(0, TYPE_BOOL, NULL, NODE_GE, $1, NULL, $3);}
    | E EQ E {$$=createTree(0, TYPE_BOOL, NULL, NODE_EQ, $1, NULL, $3);}
    | E NE E {$$=createTree(0, TYPE_BOOL, NULL, NODE_NE, $1, NULL, $3);}
    | E '+' E {$$=createTree(0, TYPE_INT, NULL, NODE_PLUS, $1, NULL, $3);}
    | E '-' E {$$=createTree(0, TYPE_INT, NULL, NODE_MINUS, $1, NULL, $3);}
    | E '/' E {$$=createTree(0, TYPE_INT, NULL, NODE_DIV, $1, NULL, $3);}
    | E '*' E {$$=createTree(0, TYPE_INT, NULL, NODE_MUL, $1, NULL, $3);}
    | '(' E ')' {$$=$2;}
    | ID {$$=$1;}
    | NUM {$$=$1;}
    ;
%%
tnode* createTree(int val, int type, char* varname, int nodetype, tnode* left, tnode* middle, tnode* right){
    tnode* temp=(tnode*)malloc(sizeof(tnode));
    temp->val=val;
    temp->type=type;
    temp->varname=varname;
    temp->nodetype=nodetype;
    temp->left=left;
    temp->middle=middle;
    temp->right=right;
    if(nodetype==NODE_PLUS || nodetype==NODE_MINUS || nodetype==NODE_MUL || nodetype==NODE_DIV ){
        if(left->type!=TYPE_INT || right->type!=TYPE_INT){
            printf("type mismatch\n");
            exit(1);
        }
        temp->type=TYPE_INT;
    }
    if(nodetype==NODE_LT || nodetype==NODE_LE || nodetype==NODE_GE || nodetype==NODE_GT || nodetype==NODE_EQ || nodetype==NODE_NE ){
        if(left->type!=TYPE_INT || right->type!=TYPE_INT){
            printf("type mismatch\n");
            exit(1);
        }
        temp->type=TYPE_BOOL;
    }
    if(nodetype==NODE_ASSIGN){
        if(right->type!=TYPE_INT){
            printf("type mismatch\n");
            exit(1);
        }
        temp->type=TYPE_NONE;
    }
    if(nodetype==NODE_IF){
        if(left->type!=TYPE_BOOL){
            printf("type mismatch\n");
            exit(1);
        }
        temp->type=TYPE_NONE;
    }
    if(nodetype==NODE_WHILE){
        if(left->type!=TYPE_BOOL){
            printf("type mismatch\n");
            exit(1);
        }
        temp->type=TYPE_NONE;
    }
    if(nodetype==NODE_WRITE){
        if(left->type!=TYPE_INT){
            printf("type mismatch\n");
            exit(1);
        }
        temp->type=TYPE_NONE;
    }
    return temp;
}
int getAddress(char* varname){
    return varname[0]-'a';
}
int evaluate(tnode* t){
    if(!t)return 0;
    switch(t->nodetype){
        case NODE_ID: {
            return memory[getAddress(t->varname)];
        }
        case NODE_NUM:{
            return t->val;
        }
        case NODE_PLUS: {
            return evaluate(t->left)+evaluate(t->right);
        }
        case NODE_MINUS: {
            return evaluate(t->left)-evaluate(t->right);
        }
        case NODE_DIV: {
            return evaluate(t->left)/evaluate(t->right);
        }
        case NODE_MUL: {
            return evaluate(t->left)*evaluate(t->right);
        }
        case NODE_LT: {
            return evaluate(t->left)<evaluate(t->right);
        }
        case NODE_LE: {
            return evaluate(t->left)<=evaluate(t->right);
        }
        case NODE_GT: {
            return evaluate(t->left)>evaluate(t->right);
        }
        case NODE_GE: {
            return evaluate(t->left)>=evaluate(t->right);
        }
        case NODE_NE: {
            return evaluate(t->left)!=evaluate(t->right);
        }
        case NODE_EQ: {
            return evaluate(t->left)==evaluate(t->right);
        }
        case NODE_CONNECT: {
            evaluate(t->left);
            evaluate(t->right);
            return 0;
        }
        case NODE_ASSIGN: {
            memory[getAddress(t->left->varname)]=evaluate(t->right);
            return 0;
        }
        case NODE_READ: {
            scanf("%d", &memory[getAddress(t->left->varname)]);
            return 0;
        }
        case NODE_WRITE: {
            printf("%d\n", evaluate(t->left));
            return 0;
        }
        case NODE_IF :{
            if(evaluate(t->left)){
                evaluate(t->middle);
            }
            else {
                evaluate(t->right);
            }
            return 0;
        }
        case NODE_WHILE:{
            while(evaluate(t->left)){
                evaluate(t->middle);
            }
            return 0;
        }
    }
    return 0;
}
void yyerror(char* s){
    printf("%s\n", s);
}
int main(){
    yyin=fopen("input.txt", "r");
    yyparse();
    fclose(yyin);
    evaluate(root);
}