%{
#include<stdio.h>
#include<stdlib.h>
#include<string.h>

int yylex();
int yyparse();
void yyerror(char* s);

#include "expr_tree.h"
struct tnode* root;
void prefix(struct tnode *);
void postfix(struct tnode *);
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
    
    return 0;
}