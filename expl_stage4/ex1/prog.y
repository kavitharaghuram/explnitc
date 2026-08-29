%{
#include "expl.h"
int yylex();
int yyparse();
void yyerror(char* s);
Gsymbol *Ghead=NULL;
int binding=4096;
Gsymbol* Lookup(char* name);
void Install(char* name, int type, int size, int isArray, int rows, int cols);
void printGsymbol();
int currentType;
tnode* root;
FILE* target_file;
int getReg();
void freeReg(int reg);
int getLabel();
int breakStack[100];
int continueStack[100];
int loopTop = -1;
void pushLoop(int breakLabel, int continueLabel);
void popLoop();
void codeGen(tnode* t);
int codeGenExpr(tnode* t);
int getAddress(tnode* t);
void writeHeader();
void writeExit();
void printTree(tnode* t, int level);
int arrayErrorLabel=-1;
%}

%union{
    tnode* node;
    int type;
}
%token BEGIN_ END READ WRITE
%token <node> NUM ID
%token IF ELSE THEN ENDIF
%token WHILE DO ENDWHILE
%token BREAK CONTINUE
%token LT GT LE GE EQ NE
%token REPEAT UNTIL
%token DECL ENDDECL INT STR

%type <node> Program
%type <node> Slist
%type <node> Stmt
%type <node> InputStmt
%type <node> OutputStmt
%type <node> AsgStmt
%type <node> IfStmt
%type <node> WhileStmt
%type <node> BreakStmt
%type <node> ContinueStmt
%type <node> RepeatStmt
%type <node> DoWhileStmt
%type <node> E
%type <type> Type

%left LT GT LE GE EQ NE
%left '+' '-'
%left '*' '/'

%%
Program
    : Declarations BEGIN_ Slist END ';' { root=$3; }
    | Declarations BEGIN_ END ';' { root=NULL; }
    ;
Declarations
    : DECL DeclList ENDDECL
    | DECL ENDDECL
    ;
DeclList
    : DeclList Decl
    | Decl
    ;
Decl
    : Type { currentType=$1; } Varlist ';'
    ;
Type
    : INT { $$= TYPE_INT; }
    | STR { $$= TYPE_STR; }
    ;
Varlist
    : Varlist ',' ID '[' NUM ']' {
        if($5->val<=0){
            printf("Array size must be positive\n");
            exit(1);
        }
            Install($3->varname, currentType, $5->val, 1, $5->val, 1);
        }
    | Varlist ',' ID '[' NUM ']' '[' NUM ']' {
            if($5->val<=0 || $8->val<=0){
                printf("Array dimensions must be positive\n");
                exit(1);
            }
            Install($3->varname, currentType, $5->val*$8->val, 1, $5->val, $8->val);
        }
    | Varlist ',' ID {
            Install($3->varname, currentType, 1, 0, 1, 1);
        }
    | ID '[' NUM ']' '[' NUM ']' {
            if($3->val<=0 || $6->val<=0){
                printf("Array dimensions must be positive\n");
                exit(1);
            }
            Install($1->varname, currentType, $3->val*$6->val, 1, $3->val, $6->val);
        }
    | ID '[' NUM ']' {
        if($3->val<=0){
            printf("Array size must be positive\n");
            exit(1);
        }
            Install($1->varname, currentType, $3->val, 1, $3->val, 1);
        }
    | ID { Install ($1->varname, currentType, 1, 0, 1, 1); }
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
    | BreakStmt {$$=$1; }
    | ContinueStmt { $$= $1;}
    | RepeatStmt { $$=$1; }
    | DoWhileStmt { $$=$1; }
    ;
InputStmt
    : READ '(' ID ')' ';' {
        Gsymbol* entry= Lookup($3->varname);
        if(entry==NULL){
            printf("Variable %s not declared\n", $3->varname);
            exit(1);
        }
        if(entry->isArray){
            printf("cannot read array %s as a scalar\n", $3->varname);
            exit(1);
        }
        $3->Gentry=entry;
        $3->type=entry->type;
        $$=createTree(0, TYPE_NONE, NULL, NODE_READ, $3, NULL, NULL); 
        }
    | READ '(' ID '[' E ']' ')' ';' {
            Gsymbol* entry=Lookup($3->varname);
            if(entry==NULL){
                printf("Variable %s is not declared\n", $3->varname);
                exit(1);
            }
            if(!entry->isArray){
                printf("%s is a scalar; cannot index it\n", $3->varname);
                exit(1);
            }
            if($5->nodetype==NODE_NUM){
                if($5->val <0 || $5->val>=entry->size){
                    printf("array index out of bounds\n");
                    exit(1);
                }
            }
            $3->Gentry=entry;
            $3->type=entry->type;
            tnode* arr=createTree(0, entry->type, NULL, NODE_ARRAY, $3, NULL, $5);
            $$=createTree(0, TYPE_NONE, NULL, NODE_READ, arr, NULL, NULL);
        }
    | READ '(' ID '[' E ']' '[' E ']' ')' ';' {
            Gsymbol* entry= Lookup($3->varname);
            if(entry==NULL){
                printf("Variable %s is not declared\n", $3->varname);
                exit(1);
            }
            if(!entry->isArray){
                printf("%s is a scalar; cant index it\n", $3->varname);
                exit(1);
            }
            if(entry->cols==1){
                printf("%s is not a 2d array\n", $3->varname);
                exit(1);
            }
            if($5->nodetype==NODE_NUM){
                if($5->val<0 || $5->val>=entry->rows){
                    printf("row idx out of bounds\n");
                    exit(1);
                }
            }
            if($8->nodetype==NODE_NUM){
                if($8->val<0 || $8->val>=entry->cols){
                    printf("col index out of bounds\n");
                    exit(1);
                }
            }
            $3->Gentry=entry;
            $3->type=entry->type;
            tnode* row=createTree(0, entry->type, NULL, NODE_ARRAY, $3, NULL, $5);
            tnode* arr=createTree(0, entry->type, NULL, NODE_ARRAY, row, NULL, $8);
            $$=createTree(0, TYPE_NONE, NULL, NODE_READ, arr, NULL, NULL);
        }
    ;
OutputStmt
    : WRITE '(' E ')' ';' {$$= createTree(0, TYPE_NONE, NULL, NODE_WRITE, $3, NULL, NULL);}
    ;
AsgStmt
    : ID '=' E ';' {
        Gsymbol* entry= Lookup($1->varname);
        if(entry==NULL){
            printf("Variable %s not declared\n", $1->varname);
            exit(1);
        }
        if(entry->isArray){
            printf("Cannot use array %s as a scalar\n", $1->varname);
            exit(1);
        }
        $1->Gentry=entry;
        $1->type=entry->type;
        $$=createTree(0, TYPE_NONE, NULL, NODE_ASSIGN, $1, NULL, $3);
        }
    | ID '[' E ']' '[' E ']' '=' E ';' {
            Gsymbol* entry= Lookup($1->varname);
            if(entry==NULL){
                printf("Variable %s not declared\n", $1->varname);
                exit(1);
            }
            if(!entry->isArray){
                printf("%s is a scalar, cant index it\n", $1->varname);
                exit(1);
            }
            if(entry->cols==1){
                printf("%s is not a 2d array\n", $1->varname);
                exit(1);
            }
            if($3->nodetype==NODE_NUM){
                if($3->val<0 || $3->val>=entry->rows){
                    printf("row index out of bounds\n");
                    exit(1);
                }
            }
            if($6->nodetype==NODE_NUM){
                if($6->val<0 || $6->val>=entry->cols){
                    printf("column index out of bounds\n");
                    exit(1);
                }
            }
            $1->Gentry=entry;
            $1->type=entry->type;
            tnode* row=createTree(0, entry->type, NULL, NODE_ARRAY, $1, NULL, $3);
            tnode* arr=createTree(0, entry->type, NULL, NODE_ARRAY, row, NULL, $6);
            $$=createTree(0, TYPE_NONE, NULL, NODE_ASSIGN, arr, NULL, $9);
        }
    | ID '[' E ']' '=' E ';' {
        Gsymbol* entry= Lookup($1->varname);
        if(entry==NULL){
            printf("Variable %s not declared\n", $1->varname);
            exit(1);
        }
        if(!entry->isArray){
            printf("%s is a scalar; cannot index it\n", $1->varname);
            exit(1);
        }
        if($3->nodetype==NODE_NUM){
            if($3->val < 0 || $3->val>=entry->size){
                printf("Array out of bounds\n");
                exit(1);
            }
        }
        $1->Gentry=entry;
        $1->type=entry->type;
        tnode* arr= createTree(0, entry->type, NULL, NODE_ARRAY, $1, NULL, $3);
        $$= createTree(0, TYPE_NONE, NULL, NODE_ASSIGN, arr, NULL, $6);
    }
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
BreakStmt
    : BREAK ';' {
        $$= createTree(0, TYPE_NONE, NULL, NODE_BREAK, NULL, NULL, NULL);
    }
    ;
ContinueStmt
    : CONTINUE ';' {
        $$= createTree(0, TYPE_NONE, NULL, NODE_CONTINUE, NULL, NULL, NULL);
    }
    ;
RepeatStmt
    : REPEAT Slist UNTIL '(' E ')' ';' {
        $$= createTree(0, TYPE_NONE, NULL, NODE_REPEAT, $2, NULL, $5);
    }
    ;
DoWhileStmt
    : DO Slist WHILE '(' E ')' ';' {
        $$= createTree(0, TYPE_NONE, NULL, NODE_DOWHILE, $2, NULL, $5);
    }
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
    | ID '[' E ']' {
            Gsymbol* entry = Lookup($1->varname);
            if(entry==NULL){
                printf("variable %s not declared\n", $1->varname);
                exit(1);
            }
            if(!entry->isArray){
                printf("%s is a scalar, cannot index it\n", $1->varname);
                exit(1);
            }
            if($3->nodetype==NODE_NUM){
                if($3->val<0 || $3->val>=entry->size){
                    printf("array index out of bounds\n");
                    exit(1);
                }
            }
            $1->Gentry=entry;
            $1->type=entry->type;
            $$= createTree(0, entry->type, NULL, NODE_ARRAY, $1, NULL, $3);
        }
    | ID '[' E ']' '[' E ']' {
            Gsymbol* entry = Lookup($1->varname);
            if(entry==NULL){
                printf("variable %s is not declared\n", $1->varname);
                exit(1);
            }
            if(!entry->isArray){
                printf("%s is a scalar cant index it\n", $1->varname);
                exit(1);
            }
            if(entry->cols==1){
                printf("%s is not a 2d array\n", $1->varname);
                exit(1);
            }
            if($3->nodetype==NODE_NUM){
                if($3->val < 0 || $3->val>=entry->rows){
                    printf("row index out of bounds\n");
                    exit(1);
                }
            }
            if($6->nodetype==NODE_NUM){
                if($6->val<0 || $6->val>=entry->cols){
                    printf("column index out of bounds\n");
                    exit(1);
                }
            }
            $1->Gentry=entry;
            $1->type=entry->type;
            tnode* row=createTree(0, entry->type, NULL, NODE_ARRAY, $1, NULL, $3);
            $$=createTree(0, entry->type, NULL, NODE_ARRAY, row, NULL, $6);
        }
    | ID {
            $$= $1; 
            Gsymbol* entry=Lookup($1->varname);
            if(entry==NULL){
                printf("Variable %s not declared\n", $1->varname);
                exit(1);
            }
            if(entry->isArray){
                printf("cannot use array %s as a scalar\n", $1->varname);
                exit(1);
            }
            $1->Gentry=entry;
            $1->type=entry->type;
        }
    ;
%%

Gsymbol* Lookup(char* name){
    Gsymbol* temp= Ghead;
    while(temp!=NULL){
        if(strcmp(temp->name, name)==0)return temp;
        temp=temp->next;
    }
    return NULL;
}
void Install(char* name, int type, int size, int isArray, int rows, int cols){
    if(Lookup(name)!=NULL){
        printf("Variable %s already declared\n", name);
        exit(1);
    }
    Gsymbol *temp=(Gsymbol*)malloc(sizeof(Gsymbol));
    temp->name=strdup(name);
    temp->type=type;
    temp->size=size;
    temp->binding=binding;
    temp->isArray=isArray;
    temp->rows=rows;
    temp->cols=cols;
    binding+=size;
    temp->next=NULL;
    if(Ghead==NULL)Ghead=temp;
    else {
        Gsymbol* ptr= Ghead;
        while(ptr->next){
            ptr=ptr->next;
        }
        ptr->next=temp;
    }
}
void printGsymbol(){
    Gsymbol* temp=Ghead;
    while(temp){
        printf("Name: %s\t", temp->name);
        if(temp->type==TYPE_INT){
            printf("Type: INT\t");
        }
        else if(temp->type==TYPE_STR){
            printf("Type: Str\t");
        }
        printf("Size: %d\tBinding: %d\n", temp->size, temp->binding);
        temp=temp->next;
    }
}
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
void pushLoop(int breakLabel, int continueLabel){
    loopTop++;
    breakStack[loopTop]=breakLabel;
    continueStack[loopTop]=continueLabel;
}
void popLoop(){
    loopTop--;
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
    fprintf(target_file, "MOV SP, %d\n", binding);
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
int getAddress(tnode* t){
    if(t==NULL || t->Gentry==NULL){
        printf("symbol table entry not found\n");
        exit(1);
    }
    return t->Gentry->binding;
}
int codeGenAddr(tnode* t){
    // a
    if(t->nodetype==NODE_ID){
        int r=getReg();
        fprintf(target_file, "MOV R%d, %d\n", r, t->Gentry->binding);
        return r;
    }
    if(t->nodetype==NODE_ARRAY && t->left->nodetype==NODE_ARRAY){
        tnode* idNode= t->left->left; //a
        tnode* iExpr= t->left->right; //row index
        tnode* jExpr= t->right; //col index;
        Gsymbol* entry= idNode->Gentry;

        int r= getReg();
        fprintf(target_file, "MOV R%d, %d\n", r, entry->binding); //base
        int ri= codeGenExpr(iExpr);
        // bound check
        if(iExpr->nodetype!=NODE_NUM){
            if(arrayErrorLabel==-1)arrayErrorLabel=getLabel();
            int rlo= getReg();
            fprintf(target_file, "MOV R%d, R%d\n", rlo, ri);
            int rzero=getReg();
            fprintf(target_file, "MOV R%d, 0\n", rzero);
            fprintf(target_file, "LT R%d, R%d\n", rlo, rzero);
            fprintf(target_file, "JNZ R%d, L%d\n", rlo, arrayErrorLabel);
            freeReg(rzero);
            freeReg(rlo);
            int rhi=getReg();
            fprintf(target_file, "MOV R%d, R%d\n", rhi, ri);
            int rrows=getReg();
            fprintf(target_file, "MOV R%d, %d\n", rrows, entry->rows);
            fprintf(target_file, "GE R%d, R%d\n", rhi, rrows);
            fprintf(target_file, "JNZ R%d, L%d\n", rhi, arrayErrorLabel);
            freeReg(rrows);
            freeReg(rhi);
        }
        int rcols= getReg();
        fprintf(target_file, "MOV R%d, %d\n", rcols, entry->cols);
        fprintf(target_file, "MUL R%d, R%d\n", ri, rcols); //ri=i*cols
        freeReg(rcols);
        fprintf(target_file, "ADD R%d, R%d\n", r, ri); //r=base+i*cols
        freeReg(ri);
        int rj= codeGenExpr(jExpr);
        //bound check
        if(jExpr->nodetype!=NODE_NUM){
            if(arrayErrorLabel==-1)arrayErrorLabel=getLabel();
            int rlo= getReg();
            fprintf(target_file, "MOV R%d, R%d\n", rlo, rj);
            int rzero=getReg();
            fprintf(target_file, "MOV R%d, 0\n", rzero);
            fprintf(target_file, "LT R%d, R%d\n", rlo, rzero);
            fprintf(target_file, "JNZ R%d, L%d\n", rlo, arrayErrorLabel);
            freeReg(rzero);
            freeReg(rlo);
            int rhi=getReg();
            fprintf(target_file, "MOV R%d, R%d\n", rhi, rj);
            int rcols2=getReg();
            fprintf(target_file, "MOV R%d, %d\n", rcols2, entry->cols);
            fprintf(target_file, "GE R%d, R%d\n", rhi, rcols2);
            fprintf(target_file, "JNZ R%d, L%d\n", rhi, arrayErrorLabel);
            freeReg(rcols2);
            freeReg(rhi);
        }
        fprintf(target_file, "ADD R%d, R%d\n", r, rj); // r=base+ i*cols+ j
        freeReg(rj);
        return r;
    }
    //a[i]
    if(t->nodetype==NODE_ARRAY){
        int r= getReg();
        fprintf(target_file, "MOV R%d, %d\n", r, t->left->Gentry->binding);
        int rindex=codeGenExpr(t->right);
        if(t->right->nodetype!=NODE_NUM){
            if(arrayErrorLabel==-1)arrayErrorLabel=getLabel();
            int passLabel=getLabel();
            int rlo=getReg();
            fprintf(target_file, "MOV R%d, R%d\n", rlo, rindex);
            int rzero=getReg();
            fprintf(target_file, "MOV R%d, 0\n", rzero);
            fprintf(target_file, "LT R%d, R%d\n", rlo, rzero);
            fprintf(target_file, "JNZ R%d, L%d\n", rlo, arrayErrorLabel);
            freeReg(rzero);
            freeReg(rlo);

            int rhi = getReg();
            fprintf(target_file, "MOV R%d, R%d\n", rhi, rindex);
            int rsize = getReg();
            fprintf(target_file, "MOV R%d, %d\n", rsize, t->left->Gentry->size);
            fprintf(target_file, "GE R%d, R%d\n", rhi, rsize);
            fprintf(target_file, "JNZ R%d, L%d\n", rhi, arrayErrorLabel);
            freeReg(rsize);
            freeReg(rhi);
        }
        fprintf(target_file, "ADD R%d, R%d\n", r, rindex);
        freeReg(rindex);
        return r;
    }
    return -1;
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
            fprintf(target_file, "MOV R%d, [%d]\n", r1, getAddress(t));
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
        case NODE_ARRAY:
            int addr=codeGenAddr(t);
            //int r= getReg();
            fprintf(target_file, "MOV R%d, [R%d]\n", addr, addr);
            //freeReg(addr);
            return addr;
        
    }
    return -1;
}
void codeGen(tnode *t){

    if(t == NULL)
        return;

    switch(t->nodetype){

        case NODE_ASSIGN:
        {
            if(t->left->nodetype == NODE_ID)
            {
                int r = codeGenExpr(t->right);

                fprintf(target_file,
                        "MOV [%d], R%d\n",
                        getAddress(t->left), r);

                freeReg(r);
            }
            else if(t->left->nodetype == NODE_ARRAY)
            {
                int addr = codeGenAddr(t->left);

                int r = codeGenExpr(t->right);

                fprintf(target_file,
                        "MOV [R%d], R%d\n",
                        addr, r);

                freeReg(r);
                freeReg(addr);
            }

            break;
        }
        case NODE_READ:
        {    int addr;
            if(t->left->nodetype==NODE_ARRAY){
                addr=codeGenAddr(t->left);
                fprintf(target_file, "MOV R1, \"Read\"\n");
                fprintf(target_file, "PUSH R1\n");

                fprintf(target_file, "MOV R1, -1\n");
                fprintf(target_file, "PUSH R1\n");

                fprintf(target_file, "PUSH R%d\n", addr);

                fprintf(target_file, "MOV R1, 0\n");
                fprintf(target_file, "PUSH R1\n");
                fprintf(target_file, "PUSH R1\n");

                fprintf(target_file, "CALL 0\n");

                fprintf(target_file, "POP R1\n");
                fprintf(target_file, "POP R1\n");
                fprintf(target_file, "POP R1\n");
                fprintf(target_file, "POP R1\n");
                fprintf(target_file, "POP R1\n");
                freeReg(addr);
            }
            else {
                addr=getAddress(t->left);
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
            }
            

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
        {   int label1=getLabel();
            int label2=getLabel();

            fprintf(target_file, "L%d:\n", label1);

            int r=codeGenExpr(t->left);

            fprintf(target_file, "JZ R%d, L%d\n", r, label2);
            freeReg(r);

            pushLoop(label2, label1);

            codeGen(t->middle);

            popLoop();

            fprintf(target_file, "JMP L%d\n", label1);
            fprintf(target_file, "L%d:\n", label2);
            break;
        }
        case NODE_BREAK:
        {
            if(loopTop>=0){
                fprintf(target_file, "JMP L%d\n", breakStack[loopTop]);
            }
            break;
        }
        case NODE_CONTINUE:
        {
            if(loopTop>=0){
                fprintf(target_file, "JMP L%d\n", continueStack[loopTop]);
            }
            break;
        }
        case NODE_REPEAT:
        {
            int bodyLabel= getLabel();
            int conditionLabel=getLabel();
            int exitLabel=getLabel();
            fprintf(target_file, "L%d:\n", bodyLabel);
            pushLoop(exitLabel, conditionLabel);
            codeGen(t->left);
            popLoop();
            fprintf(target_file, "L%d:\n", conditionLabel);
            int r= codeGenExpr(t->right);
            fprintf(target_file, "JZ R%d, L%d\n", r, bodyLabel);
            freeReg(r);
            fprintf(target_file, "L%d:\n", exitLabel);
            break;
        }
        case NODE_DOWHILE:
        {
            int bodyLabel=getLabel();
            int conditionLabel= getLabel();
            int exitLabel=getLabel();
            fprintf(target_file, "L%d:\n", bodyLabel);
            pushLoop(exitLabel, conditionLabel);
            codeGen(t->left);
            popLoop();
            fprintf(target_file, "L%d:\n", conditionLabel);
            int r= codeGenExpr(t->right);
            fprintf(target_file, "JNZ R%d, L%d\n", r, bodyLabel);
            freeReg(r);
            fprintf(target_file, "L%d:\n", exitLabel);
            break;
        }
        
    }
}

void writeArrayErrorHandler(){
    if(arrayErrorLabel==-1)return;
    fprintf(target_file, "L%d:\n", arrayErrorLabel);
    fprintf(target_file, "MOV R0, 0\n");
    fprintf(target_file, "MOV R1, \"Exit\"\n");
    fprintf(target_file, "PUSH R1\n");
    fprintf(target_file, "PUSH R0\n");
    fprintf(target_file, "PUSH R0\n");
    fprintf(target_file, "PUSH R0\n");
    fprintf(target_file, "PUSH R0\n");
    fprintf(target_file, "CALL 0\n");
}
tnode* createTree(int val, int type, char* varname, int nodetype, tnode* left, tnode* middle, tnode* right){
    tnode* temp= (tnode*)malloc(sizeof(tnode));
    temp->val=val;
    temp->type=type;
    temp->varname=varname;
    temp->nodetype=nodetype;
    temp->Gentry=NULL;
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
        if(left->type != right->type ){
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
    else if(nodetype== NODE_REPEAT || nodetype==NODE_DOWHILE){
        if(right->type!=TYPE_BOOL){
            printf("Type Mismatch\n");
            exit(1);
        }
        temp->type=TYPE_NONE;
    }
    else if(nodetype==NODE_ARRAY){
        if(right->type != TYPE_INT){
            printf("Array index must be an INT\n");
            exit(1);
        }
        temp->type=left->type;

    }
    return temp;
}
void printTree(tnode* t, int level)
{
    if(t == NULL)
        return;

    for(int i = 0; i < level; i++)
        printf("  ");

    switch(t->nodetype)
    {
        case NODE_NUM:
            printf("NUM(%d) [type=%d]\n", t->val, t->type);
            break;

        case NODE_ID:
            printf("ID(%s) [type=%d, binding=%d]\n",
                   t->varname,
                   t->type,
                   t->Gentry->binding);
            break;

        case NODE_PLUS:
            printf("PLUS\n");
            break;

        case NODE_MINUS:
            printf("MINUS\n");
            break;

        case NODE_MUL:
            printf("MUL\n");
            break;

        case NODE_DIV:
            printf("DIV\n");
            break;

        case NODE_LT:
            printf("LT\n");
            break;

        case NODE_GT:
            printf("GT\n");
            break;

        case NODE_LE:
            printf("LE\n");
            break;

        case NODE_GE:
            printf("GE\n");
            break;

        case NODE_EQ:
            printf("EQ\n");
            break;

        case NODE_NE:
            printf("NE\n");
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
            printf("CONNECT\n");
            break;

        case NODE_IF:
            printf("IF\n");
            break;

        case NODE_WHILE:
            printf("WHILE\n");
            break;

        case NODE_BREAK:
            printf("BREAK\n");
            break;

        case NODE_CONTINUE:
            printf("CONTINUE\n");
            break;

        case NODE_REPEAT:
            printf("REPEAT\n");
            break;

        case NODE_DOWHILE:
            printf("DOWHILE\n");
            break;

        case NODE_ARRAY:
            printf("ARRAY [type %d]\n", t->type);
            break;

        default:
            printf("UNKNOWN NODE\n");
    }

    printTree(t->left, level + 1);
    printTree(t->middle, level + 1);
    printTree(t->right, level + 1);
}

void yyerror(char* s){
    printf("%s\n", s);
}
int main()
{
    yyparse();

    printGsymbol();
    printTree(root, 0);
    target_file=fopen("output.xsm", "w");
    writeHeader();
    codeGen(root);
    writeArrayErrorHandler();
    writeExit();
    fclose(target_file);
    return 0;
}