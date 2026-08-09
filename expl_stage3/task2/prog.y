%{
#include "expl.h"
int yylex();
int yyparse();
void yyerror(char* s);
tnode* root;
FILE* target_file;
int getReg();
void freeReg(int reg);
int getLabel();
void codeGen(tnode* t);
int codeGenExpr(tnode* t);
int getAddress(char* varname);
void writeHeader();
void writeExit();
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
    : WRITE '(' E ')' ';' {$$= createTree(0, TYPE_NONE, NULL, NODE_WRITE, $3, NULL, NULL);}
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

int regCount=-1;
int getReg(){
    return ++regCount;
}
void freeReg(int reg){
    regCount--;
}
int labelCount=0;
int getLabel(){
    return labelCount++;
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
int getAddress(char* varname){
    return varname[0]-'a'+4096;
}
int codeGenExpr(tnode* t){
    int r1, r2;
    if(t==NULL)return -1;
    switch(t->nodetype){
        case NODE_NUM:
            r1=getReg();
            fprintf(target_file, "MOV R%d, %d\n", r1, t->val);
            return r1;
        case NODE_ID:
            r1=getReg();
            fprintf(target_file, "MOV R%d, [%d]\n", r1, getAddress(t->varname));
            return r1;
        case NODE_PLUS:
            r1=codeGenExpr(t->left);
            r2=codeGenExpr(t->right);
            fprintf(target_file, "ADD R%d, R%d\n", r1, r2);
            freeReg(r2);
            return r1;
        case NODE_MINUS:
            r1=codeGenExpr(t->left);
            r2=codeGenExpr(t->right);
            fprintf(target_file, "SUB R%d, R%d\n", r1, r2);
            freeReg(r2);
            return r1;
        case NODE_MUL:
            r1=codeGenExpr(t->left);
            r2=codeGenExpr(t->right);
            fprintf(target_file, "MUL R%d, R%d\n", r1, r2);
            freeReg(r2);
            return r1;
        case NODE_DIV:
            r1=codeGenExpr(t->left);
            r2=codeGenExpr(t->right);
            fprintf(target_file, "DIV R%d, R%d\n", r1, r2);
            freeReg(r2);
            return r1;
        case NODE_LT:
            r1= codeGenExpr(t->left);
            r2= codeGenExpr(t->right);
            fprintf(target_file, "LT R%d, R%d\n", r1, r2);
            freeReg(r2);
            return r1;
        case NODE_GT:
            r1= codeGenExpr(t->left);
            r2= codeGenExpr(t->right);
            fprintf(target_file, "GT R%d, R%d\n", r1, r2);
            freeReg(r2);
            return r1;
        case NODE_LE:
            r1= codeGenExpr(t->left);
            r2= codeGenExpr(t->right);
            fprintf(target_file, "LE R%d, R%d\n", r1, r2);
            freeReg(r2);
            return r1;
        case NODE_GE:
            r1= codeGenExpr(t->left);
            r2= codeGenExpr(t->right);
            fprintf(target_file, "GE R%d, R%d\n", r1, r2);
            freeReg(r2);
            return r1;
        case NODE_EQ:
            r1= codeGenExpr(t->left);
            r2= codeGenExpr(t->right);
            fprintf(target_file, "EQ R%d, R%d\n", r1, r2);
            freeReg(r2);
            return r1;
        case NODE_NE:
            r1= codeGenExpr(t->left);
            r2= codeGenExpr(t->right);
            fprintf(target_file, "NE R%d, R%d\n", r1, r2);
            freeReg(r2);
            return r1;
        
    }
    return -1;
}
void codeGen(tnode *t){

    if(t == NULL)
        return;

    switch(t->nodetype){

        case NODE_ASSIGN:
        {    int r=codeGenExpr(t->right);
            fprintf(target_file, "MOV [%d], R%d\n", getAddress(t->left->varname), r);
            freeReg(r);
            break;
        }
        case NODE_READ:
        {    int addr=getAddress(t->left->varname);
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

            break;
        }
        case NODE_WRITE:
        {    int r= codeGenExpr(t->left);
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

            freeReg(r);

            break;
        }
        case NODE_CONNECT:
        {   codeGen(t->left);
            codeGen(t->right);
            break;
        }
        case NODE_IF:
        {    if(t->right==NULL){
                int label1=getLabel();
                int r= codeGenExpr(t->left);
                fprintf(target_file, "JZ R%d, L%d\n", r, label1);
                freeReg(r);
                codeGen(t->middle);
                fprintf(target_file, "L%d:\n", label1);
                break;
            }
            else {
                int label1=getLabel();
                int label2=getLabel();
                int r= codeGenExpr(t->left);
                fprintf(target_file, "JZ R%d, L%d\n", r, label1);
                freeReg(r);
                codeGen(t->middle);
                fprintf(target_file, "JMP L%d\n", label2);
                fprintf(target_file, "L%d:\n", label1);
                codeGen(t->right);
                fprintf(target_file, "L%d:\n", label2);
            }
            break;
            
        }
        case NODE_WHILE:
        {    int label1=getLabel();
            int label2=getLabel();
            fprintf(target_file, "L%d:\n", label1);
            int r=codeGenExpr(t->left);
            fprintf(target_file, "JZ R%d, L%d\n", r, label2);
            freeReg(r);
            codeGen(t->middle);
            fprintf(target_file, "JMP L%d\n", label1);
            fprintf(target_file, "L%d:\n", label2);
            break;
        }
    }
}
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

void yyerror(char* s){
    printf("%s\n", s);
}
int main()
{
    yyparse();

    target_file = fopen("output.xsm", "w");

    if(target_file == NULL)
    {
        printf("Cannot open output file\n");
        return 1;
    }

    writeHeader();

    codeGen(root);

    writeExit();

    fclose(target_file);

    return 0;
}