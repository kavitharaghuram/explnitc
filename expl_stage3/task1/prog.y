%{
#include "expl.h"
int yylex();
int yyparse();
void yyerror(char* s);
tnode* root;
%}

%union{
    tnode* node;
}
%token BEGIN_ END READ WRITE
%token <node> NUM ID
%token IF ELSE THEN ENDIF
%token WHILE DO ENDWHILE
%token LT GT LE GE EQ NE

%type <node> Program
%type <node> Slist
%type <node> Stmt
%type <node> InputStmt
%type <node> OutputStmt
%type <node> AsgStmt
%type <node> IfStmt
%type <node> WhileStmt
%type <node> E

%left LT GT LE GE EQ NE
%left '+' '-'
%left '*' '/'

%%
Program
    : BEGIN_ Slist END ';' { root=$2; }
    | BEGIN_ END ';' { root=NULL; }
    ;
Slist
    : Slist Stmt { $$= createTree(0, TYPE_INT, NULL, NODE_CONNECT, $1, NULL, $2);}
    | Stmt { $$= $1; }
    ;
Stmt
    : InputStmt { $$=$1 ;}
    | OutputStmt { $$=$1; }
    | AsgStmt { $$= $1; }
    | IfStmt {$$=$1;}
    | WhileStmt {$$=$1; }
    ;
InputStmt
    : READ '(' ID ')' ';' {$$=createTree(0, TYPE_NONE, NULL, NODE_READ, $3, NULL, NULL); }
    ;
OutputStmt
    : WRITE '(' E ')' ';' {$$= createTree(0, TYPE_INT, NULL, NODE_WRITE, $3, NULL, NULL);}
    ;
AsgStmt
    : ID '=' E ';' {$$=createTree(0, TYPE_NONE, NULL, NODE_ASSIGN, $1, NULL, $3);}
    ;
IfStmt      
    : IF '(' E ')' THEN Slist ELSE Slist ENDIF ';'{
        $$= createTree(0, TYPE_NONE, NULL, NODE_IF, $3, $6, $8);
    }
    | IF '(' E ')' THEN Slist ENDIF ';' {
        $$= createTree(0, TYPE_NONE, NULL, NODE_IF, $3, $6, NULL);
    }
    ;
WhileStmt
    : WHILE '(' E ')' DO Slist ENDWHILE ';' {
        $$= createTree(0, TYPE_NONE, NULL, NODE_WHILE, $3, $6, NULL);
    }
    ;
E
    : E '+' E {$$= createTree(0, TYPE_INT,  NULL, NODE_PLUS, $1, NULL, $3); }
    | E '-' E {$$= createTree(0, TYPE_INT,  NULL, NODE_MINUS, $1, NULL, $3); }
    | E '*' E {$$= createTree(0, TYPE_INT,  NULL, NODE_MUL, $1, NULL, $3); }
    | E '/' E {$$= createTree(0, TYPE_INT,  NULL, NODE_DIV, $1, NULL, $3); }
    | E LT E { $$ = createTree(0, TYPE_BOOL, NULL, NODE_LT, $1, NULL, $3); }
    | E GT E { $$ = createTree(0, TYPE_BOOL, NULL, NODE_GT, $1, NULL, $3); }
    | E LE E { $$ = createTree(0, TYPE_BOOL, NULL, NODE_LE, $1, NULL, $3); }
    | E GE E { $$ = createTree(0, TYPE_BOOL, NULL, NODE_GE, $1, NULL, $3); }
    | E EQ E { $$ = createTree(0, TYPE_BOOL, NULL, NODE_EQ, $1, NULL, $3); }
    | E NE E { $$ = createTree(0, TYPE_BOOL, NULL, NODE_NE, $1, NULL, $3); }
    | '(' E ')' {$$= $2; }
    | NUM {$$= $1; }
    | ID {$$= $1; }
    ;
%%

tnode* createTree(int val, int type, char* varname, int nodetype, tnode* left, tnode* middle, tnode* right){
    tnode* temp= (tnode*)malloc(sizeof(tnode));
    temp->val=val;
    temp->type=type;
    temp->varname=varname;
    temp->nodetype=nodetype;
    temp->left=left;
    temp->middle=middle;
    temp->right=right;

    if(nodetype==NODE_PLUS || nodetype==NODE_MINUS || nodetype==NODE_MUL || nodetype==NODE_DIV){
        if(left->type !=TYPE_INT || right->type !=TYPE_INT){
            printf("Type Mismatch\n");
            exit(1);
        }
        temp->type=TYPE_INT;
    }
    else if(nodetype== NODE_LT || nodetype== NODE_GT || nodetype== NODE_LE || nodetype== NODE_GE || nodetype== NODE_EQ || nodetype==NODE_NE){
        if(left->type!=TYPE_INT || right->type != TYPE_INT){
            printf("Type Mismatch\n");
            exit(1);
        }
        temp->type=TYPE_BOOL;
    }
    else if (nodetype==NODE_ASSIGN){
        if(right->type!=TYPE_INT){
            printf("Type Mismatch\n");
            exit(1);
        }
        temp->type=TYPE_NONE;
    }
    else if(nodetype==NODE_IF){
        if(left->type != TYPE_BOOL){
            printf("Type Mismatch\n");
            exit(1);
        }
        temp->type=TYPE_NONE;
    }
    else if(nodetype==NODE_WHILE){
        if(left->type!=TYPE_BOOL){
            printf("Type Mismatch\n");
            exit(1);
        }
        temp->type=TYPE_NONE;
    }
    else if(nodetype== NODE_WRITE){
        if(left->type!=TYPE_INT){
            printf("Type Mismatch\n");
            exit(1);
        }
        temp->type=TYPE_NONE;
    }
    return temp;
}
void printTree(struct tnode *t){
    if(t==NULL)
        return;

    switch(t->nodetype){

        case NODE_NUM:
            printf("NUM(%d)\n", t->val);
            break;

        case NODE_ID:
            printf("ID(%s)\n", t->varname);
            break;

        case NODE_PLUS:
            printf("+\n");
            break;

        case NODE_MINUS:
            printf("-\n");
            break;

        case NODE_MUL:
            printf("*\n");
            break;

        case NODE_DIV:
            printf("/\n");
            break;

        case NODE_ASSIGN:
            printf("ASSIGN\n");
            break;

        case NODE_READ:
            printf("READ\n");
            break;

        case NODE_WRITE:
            printf("WRITE\n");
            break;

        case NODE_CONNECT:
            printf("CONNECTOR\n");
            break;

        case NODE_LT:
            printf("<\n");
            break;

        case NODE_GT:
            printf(">\n");
            break;

        case NODE_LE:
            printf("<=\n");
            break;

        case NODE_GE:
            printf(">=\n");
            break;

        case NODE_EQ:
            printf("==\n");
            break;

        case NODE_NE:
            printf("!=\n");
            break;

        case NODE_IF:
            printf("IF\n");
            break;

        case NODE_WHILE:
            printf("WHILE\n");
            break;
                default:
                    printf("UNKNOWN\n");
            }

    printTree(t->left);
    printTree(t->middle);
    printTree(t->right);
}
void yyerror(char* s){
    printf("%s\n", s);
}
int main(){
    yyparse();
    printf("AST created successfully!\n\n");
    printTree(root);
    return 0;
}