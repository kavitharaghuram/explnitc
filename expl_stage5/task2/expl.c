#include "expl.h"
Gsymbol *Ghead=NULL;
int binding=4096;
int functionLabel=0;

Gsymbol *currentFunction = NULL;
Lsymbol *Lhead = NULL;
int localBinding = 0;
int breakStack[100];
int continueStack[100];
int loopTop = -1;
int arrayErrorLabel=-1;
Gsymbol* Lookup(char* name){
    Gsymbol* temp= Ghead;
    while(temp!=NULL){
        if(strcmp(temp->name, name)==0)return temp;
        temp=temp->next;
    }
    return NULL;
}
Lsymbol* LookupLocal(char* name){
    Lsymbol* temp = Lhead;
    while(temp != NULL){
        if(strcmp(temp->name, name) == 0)
            return temp;
        temp = temp->next;
    }
    return NULL;
}
Gsymbol* LookupGlobal(char *name){
    return Lookup(name);
}
Paramstruct* createParam(char* name, int type){
    Paramstruct *temp=(Paramstruct*)malloc(sizeof(Paramstruct));
    temp->name=name;
    temp->type=type;
    temp->next=NULL;
    return temp;
}
void Install(char* name, int type, int size, int isArray, int rows, int cols,
             int isPointer, Paramstruct *paramlist, int isFunction){
    if(Lookup(name)!=NULL){
        printf("Multiple declaration of %s\n", name);
        exit(1);
    }
    Gsymbol *temp=(Gsymbol*)malloc(sizeof(Gsymbol));
    temp->name=strdup(name);
    temp->type=type;
    temp->size=size;
    temp->binding = isFunction ? -1 : binding;   // functions don't occupy data memory
    temp->paramlist=paramlist;
    temp->isFunction=isFunction;
    temp->flabel = isFunction ? functionLabel++ : -1;
    temp->isArray=isArray;
    temp->rows=rows;
    temp->cols=cols;
    temp->isPointer=isPointer;
    temp->next=NULL;

    if(!isFunction) binding += size;

    if(Ghead==NULL) Ghead=temp;
    else {
        Gsymbol* ptr=Ghead;
        while(ptr->next) ptr=ptr->next;
        ptr->next=temp;
    }
}
void InstallLocal(char *name, int type){
    if(LookupLocal(name) != NULL){
        printf("Multiple declaration of local variable %s\n", name);
        exit(1);
    }
    Lsymbol *temp = (Lsymbol*)malloc(sizeof(Lsymbol));
    temp->name = strdup(name);
    temp->type = type;
    temp->binding = localBinding;
    temp->next = NULL;
    localBinding++;
    if(Lhead == NULL){
        Lhead = temp;
    }
    else{
        Lsymbol *ptr = Lhead;
        while(ptr->next != NULL)
            ptr = ptr->next;
        ptr->next = temp;
    }
}
void printGsymbol(){
    Gsymbol* temp=Ghead;
    while(temp){
        printf("Name: %s\tType: %s\t", temp->name,
               temp->type==TYPE_INT ? "INT" : "STR");
        if(temp->isFunction){
            printf("FUNCTION\tflabel: F%d\tParams: (", temp->flabel);
            Paramstruct* p = temp->paramlist;
            while(p){
                printf("%s %s", p->type==TYPE_INT?"int":"str", p->name);
                if(p->next) printf(", ");
                p=p->next;
            }
            printf(")\n");
        } else if(temp->isArray){
            printf("ARRAY size=%d binding=%d\n", temp->size, temp->binding);
        } else {
            printf("VAR binding=%d\n", temp->binding);
        }
        temp=temp->next;
    }
}
void printLsymbol(){
    Lsymbol *temp = Lhead;
    while(temp != NULL){
        printf("Name: %s\tType: %s\tBinding: %d\n",
               temp->name,
               temp->type == TYPE_INT ? "INT" : "STR",
               temp->binding);

        temp = temp->next;
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
        case NODE_ADDR:
            return codeGenAddr(t->left);
        case NODE_DEREF:
            int r=codeGenExpr(t->left);
            fprintf(target_file, "MOV R%d, [R%d]\n", r, r);
            return r;
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
            else if(t->left->nodetype==NODE_DEREF){
                int addr=codeGenExpr(t->left->left);
                int r= codeGenExpr(t->right);
                fprintf(target_file, "MOV [R%d], R%d\n", addr, r);
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
    temp->Lentry=NULL;
    temp->left=left;
    temp->middle=middle;
    temp->right=right;
    temp->isPointer=0;
    temp->args = NULL;
    temp->next = NULL;
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
        printf("LEFT: type=%d pointer=%d\n",
           left->type, left->isPointer);

    printf("RIGHT: type=%d pointer=%d\n",
           right->type, right->isPointer);
        if(left->type != right->type || left->isPointer != right->isPointer){
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
            if(t->Lentry != NULL){
                printf("ID(%s) [type=%d, pointer=%d, local binding=%d]\n",
                    t->varname,
                    t->type,
                    t->isPointer,
                    t->Lentry->binding);
            }
            else if(t->Gentry != NULL){
                printf("ID(%s) [type=%d, pointer=%d, global binding=%d]\n",
                    t->varname,
                    t->type,
                    t->isPointer,
                    t->Gentry->binding);
            }
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
        
        case NODE_ADDR:
            printf("ADDR\n");
            break;

        case NODE_DEREF:
            printf("DEREF\n");
            break; 

        case NODE_CALL:
            printf("CALL(%s)\n", t->varname);
            break;

        default:
            printf("UNKNOWN NODE\n");
    }

    printTree(t->left, level + 1);
    printTree(t->middle, level + 1);
    printTree(t->right, level + 1);

    if(t->nodetype == NODE_CALL){
    tnode *a = t->args;
        while(a != NULL){
            printTree(a, level + 1);
            a = a->next;
        }
    }
}
void setupFunction(char *name, int returnType, Paramstruct *params){
    currentFunction = Lookup(name);

    if(currentFunction == NULL){
        printf("Function %s not declared\n", name);
        exit(1);
    }

    if(!currentFunction->isFunction){
        printf("%s is not a function\n", name);
        exit(1);
    }

    /* Check return type */
    if(returnType != currentFunction->type){
        printf("Return type mismatch for function %s\n", name);
        exit(1);
    }

    /* Check parameters */
    Paramstruct *decl = currentFunction->paramlist;
    Paramstruct *def = params;

    while(decl != NULL && def != NULL){

        if(decl->type != def->type){
            printf("Parameter type mismatch in function %s\n", name);
            exit(1);
        }

        if(strcmp(decl->name, def->name) != 0){
            printf("Parameter name mismatch in function %s\n", name);
            exit(1);
        }

        decl = decl->next;
        def = def->next;
    }
    
    /* One list longer than the other */
    if(decl != NULL || def != NULL){
        printf("Parameter count mismatch in function %s\n", name);
        exit(1);
    }
    if(strcmp(name, "main") == 0){
        if(returnType != TYPE_INT){
            printf("main must have return type int\n");
            exit(1);
        }

        if(params != NULL){
            printf("main cannot have parameters\n");
            exit(1);
        }
    }
    /* Create local table */
    Lhead = NULL;
    localBinding = 0;

    Paramstruct *p = params;

    while(p != NULL){
        InstallLocal(p->name, p->type);
        p = p->next;
    }
}
void resolveID(tnode *node){
    Lsymbol *lentry = LookupLocal(node->varname);

    if(lentry != NULL){
        node->Lentry = lentry;
        node->type = lentry->type;
        node->isPointer = 0;
        return;
    }

    Gsymbol *gentry = Lookup(node->varname);

    if(gentry == NULL){
        printf("Variable %s not declared\n", node->varname);
        exit(1);
    }
    if(gentry->isFunction){
    printf("%s is a function, not a variable\n", node->varname);
    exit(1);
}
    node->Gentry = gentry;
    node->type = gentry->type;
    node->isPointer = gentry->isPointer;
}
void yyerror(char* s){
    printf("%s\n", s);
}
