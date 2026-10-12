%{
#include<stdio.h>
#include<stdlib.h>
#include<string.h>
#include "y.tab.h"
#include "expl.h"
int yylex();
void yyerror(char* s);

tnode* root=NULL;
void printTree(tnode* root);
tnode* createTree(int val, int type, char* varname, int node_type, tnode* left, tnode* right);
int memory[26];
int evaluate(tnode* root);
int getAddress(char* varname);
extern FILE *yyin;
%}
%union{
    struct tnode* node;
}
%token BEGIN_ END READ WRITE
%token<node> NUM ID
%type<node> Program Slist Stmt InputStmt OutputStmt AsgStmt E
%left '+' '-'
%left '*' '/'
%%

Program: BEGIN_ Slist END ';' {root=$2;}
        | BEGIN_ END ';' {root=NULL;}
        ;
Slist: Slist Stmt {$$=createTree(0, TYPE_INT, NULL, NODE_CONNECT, $1, $2);}
        | Stmt {$$=$1;}
        ;
Stmt: InputStmt { $$=$1;}
    | OutputStmt {$$=$1;}
    | AsgStmt {$$=$1;}
    ;
InputStmt: READ '(' ID ')' ';' {$$=createTree(0, TYPE_INT, NULL, NODE_READ, $3, NULL);};
OutputStmt: WRITE '(' E ')' ';' {$$=createTree(0, TYPE_INT, NULL, NODE_WRITE, $3, NULL);};
AsgStmt: ID '=' E ';' {$$=createTree(0, TYPE_INT, NULL, NODE_ASSIGN, $1, $3);};
E: E '+' E {$$=createTree(0, TYPE_INT, NULL, NODE_PLUS, $1, $3);}
    |E '*' E {$$=createTree(0, TYPE_INT, NULL, NODE_MUL, $1, $3);}
    |E '-' E {$$=createTree(0, TYPE_INT, NULL, NODE_MINUS, $1, $3);}
    |E '/' E {$$=createTree(0, TYPE_INT, NULL, NODE_DIV, $1, $3);}
    | '(' E ')' {$$=$2;}
    | NUM {$$=$1;}
    | ID {$$=$1;}
    ;
%%

tnode* createTree(int val, int type, char* varname, int node_type, tnode* left, tnode* right){
    tnode* temp=(tnode*)malloc(sizeof(tnode));
    temp->val=val;
    temp->type=type;
    temp->varname=varname;
    temp->node_type=node_type;
    temp->left=left;
    temp->right=right;
    return temp;
}
void printTree(tnode* t){
    if(!t)return;
    switch(t->node_type){
        case NODE_NUM: {
            printf("NUM(%d)\n", t->val);
            break;
        }
        case NODE_ID: {
            printf("ID(%s)\n", t->varname);
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
        case NODE_ASSIGN: {
            printf("ASSIGN\n");
            break;
        }
        case NODE_CONNECT: {
            printf("CONNECT\n");
            break;
        }
        default: 
            printf("UNKNOWN\n");
    }
    printTree(t->left);
    printTree(t->right);
}
int getAddress(char* varname){
    return (varname[0]-'a');
}
int evaluate(tnode* t){
    if(!t)return 0;
    switch(t->node_type){
        case NODE_NUM: {
            return t->val;
            break;
        }
        case NODE_ID: {
            return memory[getAddress(t->varname)];
            break;
        }
        case NODE_PLUS: {
            return evaluate(t->left)+evaluate(t->right);
            break;
        }
        case NODE_MINUS: {
            return evaluate(t->left)-evaluate(t->right);
            break;
        }
        case NODE_MUL: {
            return evaluate(t->left)*evaluate(t->right);
            break;
        }
        case NODE_DIV: {
            return evaluate(t->left)/evaluate(t->right);
            break;
        }
        case NODE_ASSIGN: {
            memory[getAddress(t->left->varname)]=evaluate(t->right);
            return 0;
            break;
        }
        case NODE_READ: {
            scanf("%d", &memory[getAddress(t->left->varname)]);
            return 0;
            break;
        }
        case NODE_WRITE: {
            printf("%d\n", evaluate(t->left));
            return 0;
            break;
        }
        case NODE_CONNECT: {
            evaluate(t->left);
            evaluate(t->right);
            return 0;
        }
    }
}
void yyerror(char* s){
    printf("%s", s);
}
int main(){
    yyin = fopen("input.txt", "r");
    if (yyin == NULL) {
        printf("Cannot open input file\n");
        return 1;
    }
    yyparse();
    fclose(yyin);
    //printTree(root);
    evaluate(root);
    return 0;
}