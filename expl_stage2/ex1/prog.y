%{
#include "expl.h"
int yylex();
int yyparse();
void yyerror(char* s);
tnode* root;
FILE* target_file;
int memory[26];
int evaluate(tnode* t);
extern FILE *yyin;
%}

%union{
    tnode* node;
}
%token BEGIN_ END READ WRITE
%token <node> NUM ID

%type <node> Program
%type <node> Slist
%type <node> Stmt
%type <node> InputStmt
%type <node> OutputStmt
%type <node> AsgStmt
%type <node> E

%left '+' '-'
%left '*' '/'

%%
Program
    : BEGIN_ Slist END ';' { root=$2; }
    | BEGIN_ END ';' { root=NULL; }
    ;
Slist
    : Slist Stmt { $$= createTree(0, TYPE_INT, NULL, NODE_CONNECT, $1, $2);}
    | Stmt { $$= $1; }
    ;
Stmt
    : InputStmt { $$=$1 ;}
    | OutputStmt { $$=$1; }
    | AsgStmt { $$= $1; }
    ;
InputStmt
    : READ '(' ID ')' ';' {$$=createTree(0, TYPE_INT, NULL, NODE_READ, $3, NULL); }
    ;
OutputStmt
    : WRITE '(' E ')' ';' {$$= createTree(0, TYPE_INT, NULL, NODE_WRITE, $3, NULL);}
    ;
AsgStmt
    : ID '=' E ';' {$$=createTree(0, TYPE_INT, NULL, NODE_ASSIGN, $1, $3);}
    ;
E
    : E '+' E {$$= createTree(0, TYPE_INT,  NULL, NODE_PLUS, $1, $3); }
    | E '-' E {$$= createTree(0, TYPE_INT,  NULL, NODE_MINUS, $1, $3); }
    | E '*' E {$$= createTree(0, TYPE_INT,  NULL, NODE_MUL, $1, $3); }
    | E '/' E {$$= createTree(0, TYPE_INT,  NULL, NODE_DIV, $1, $3); }
    | '(' E ')' {$$= $2; }
    | NUM {$$= $1; }
    | ID {$$= $1; }
    ;
%%

tnode* createTree(int val, int type, char* varname, int nodetype, tnode* left, tnode* right){
    tnode* temp= (tnode*)malloc(sizeof(tnode));
    temp->val=val;
    temp->type=type;
    temp->varname=varname;
    temp->nodetype=nodetype;
    temp->left=left;
    temp->right=right;
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
    if(t==NULL)return 0;
    switch(t->nodetype){
        case NODE_NUM:
            return t->val;
        case NODE_ID:
            return memory[getAddress(t->varname)];
        case NODE_PLUS: 
            return evaluate(t->left)+evaluate(t->right);
        case NODE_MINUS:
            return evaluate(t->left)-evaluate(t->right);
        case NODE_MUL:
            return evaluate(t->left)*evaluate(t->right);
        case NODE_DIV:
            return evaluate(t->left)/evaluate(t->right);
        case NODE_ASSIGN:
            memory[getAddress(t->left->varname)]=evaluate(t->right);
            return 0;
        case NODE_READ:
            scanf("%d", &memory[getAddress(t->left->varname)]);
            return 0;
        case NODE_WRITE:
            printf("%d\n", evaluate(t->left));
            return 0;
        case NODE_CONNECT:
            evaluate(t->left);
            evaluate(t->right);
            return 0;
    }
    return 0;
}

void yyerror(char* s){
    printf("%s\n", s);
}
int main(){
    yyin = fopen("input.txt", "r");
    if (yyin == NULL) {
        printf("Cannot open input file\n");
        return 1;
    }

    yyparse();
    fclose(yyin);

    printf("\n");
    evaluate(root);
    return 0;
}