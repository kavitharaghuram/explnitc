%{
#include "expl.h"
int yylex();
int yyparse();
void yyerror(char* s);
tnode* root;
FILE* target_file;
int reg=-1;
int getReg();
void freeReg();
int codeGen(tnode* t);
void writeHeader();
void writeExit();
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
int getReg(){
    return ++reg;
}
void freeReg(){
    reg--;
}
int getAddress(char* varname){
    return 4096 + (varname[0]-'a');
}

int codeGen(tnode* t){
    if(t==NULL)return -1;
    //NUM
    if(t->nodetype==NODE_NUM){
        int r=getReg();
        fprintf(target_file, "MOV R%d, %d\n", r, t->val);
        return r;
    }
    //ID node
    if(t->nodetype==NODE_ID){
        int r=getReg();
        int addr=getAddress(t->varname);
        fprintf(target_file, "MOV R%d, [%d]\n", r, addr);
        return r;
    }
    if(t->nodetype==NODE_PLUS || t->nodetype==NODE_MINUS || t->nodetype == NODE_MUL || t->nodetype==NODE_DIV){
        int left=codeGen(t->left);
        int right=codeGen(t->right);
        switch(t->nodetype){
            case NODE_PLUS :
                fprintf(target_file, "ADD R%d, R%d\n", left, right);
                break;
            case NODE_MINUS :
                fprintf(target_file, "SUB R%d, R%d\n", left, right);
                break;
            case NODE_MUL :
                fprintf(target_file, "MUL R%d, R%d\n", left, right);
                break;
            case NODE_DIV :
                fprintf(target_file, "DIV R%d, R%d\n", left, right);
                break;
            
        }
        freeReg();
        return left;
    }
    if(t->nodetype==NODE_ASSIGN){
        int r= codeGen(t->right);
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
    if(t->nodetype==NODE_READ){
        int addr=getAddress(t->left->varname);
        fprintf(target_file, "MOV R0, \"Read\"\n");
        fprintf(target_file, "PUSH R0\n");

        fprintf(target_file, "MOV R0, -1\n");
        fprintf(target_file, "PUSH R0\n");

        fprintf(target_file,"MOV R0, %d\n", addr);
        fprintf(target_file,"PUSH R0\n");

        fprintf(target_file,"MOV R0, 0\n");
        fprintf(target_file,"PUSH R0\n");
        fprintf(target_file,"PUSH R0\n");

        fprintf(target_file, "CALL 0\n");

        fprintf(target_file, "POP R0\n");
        fprintf(target_file, "POP R0\n");
        fprintf(target_file, "POP R0\n");
        fprintf(target_file, "POP R0\n");
        fprintf(target_file, "POP R0\n");

        return -1;
    }
    if(t->nodetype == NODE_WRITE){

        int r = codeGen(t->left);

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
    fprintf(target_file,"BRKP\n");
    fprintf(target_file,"MOV SP, 4122\n");
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
    if(target_file == NULL){
        printf("Cannot open output file\n");
        return 1;
    }
    writeHeader();
    codeGen(root);
    writeExit();
    fclose(target_file);
    printTree(root);
    return 0;
}