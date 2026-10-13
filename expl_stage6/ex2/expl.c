#include "expl.h"
Gsymbol *Ghead=NULL;
int binding=4096;
int functionLabel=0;
int paramCounter=0;
int localVarCounter=0;
Gsymbol *currentFunction = NULL;
Lsymbol *Lhead = NULL;
int localBinding = 0;
int breakStack[100];
int continueStack[100];
int loopTop = -1;
int arrayErrorLabel=-1;
int libMode=0;


tnode* buildFieldAccess(tnode *base, char *fieldName){
    if(!isUserType(base->type)){
        printf("'.' used on a non-user-defined type\n");
        exit(1);
    }
    Fieldlist *f = FLookup(base->type, fieldName);
    if(f == NULL){
        printf("Type %s has no field %s\n", base->type->name, fieldName);
        exit(1);
    }
    tnode *node = createTree(0, f->type, NULL, NODE_FIELD, base, NULL, NULL);
    node->fieldOffset = f->fieldIndex;
    return node;
}
Typetable *TypeHead = NULL, *tint, *tstr, *tbool, *tvoid, *tnull;

void TypeTableCreate(){
    tint  = TInstall("int", 0, NULL);
    tstr  = TInstall("str", 0, NULL);
    tbool = TInstall("boolean", 0, NULL);
    tvoid = TInstall("void", 0, NULL);
    tnull = TInstall("null", 0, NULL);
}
Typetable* TInstall(char *name, int size, Fieldlist *fields){
    if(TLookup(name)){ printf("Multiple declaration of type %s\n", name); exit(1); }
    Typetable *t = calloc(1, sizeof(Typetable));
    t->name = strdup(name); t->size = size; t->fields = fields;
    if(!TypeHead) TypeHead = t;
    else { Typetable *p = TypeHead; while(p->next) p = p->next; p->next = t; }
    return t;
}
Typetable* TLookup(char *name){
    for(Typetable *t = TypeHead; t; t = t->next) if(!strcmp(t->name, name)) return t;
    return NULL;
}
Fieldlist* FLookup(Typetable *t, char *fieldName){
    for(Fieldlist *f = t->fields; f; f = f->next) if(!strcmp(f->name, fieldName)) return f;
    return NULL;
}
int isUserType(Typetable *t){ return t && t->fields != NULL; }

// name equivalence: same entry, except null may go into any user type
int typesCompatible(Typetable *dst, Typetable *src){
    return dst == src || (isUserType(dst) && src == tnull);
}

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
Paramstruct* createParam(char* name,Typetable* type, int isPointer){
    Paramstruct *temp=(Paramstruct*)calloc(1, sizeof(Paramstruct));
    temp->name=name;
    temp->type=type;
    temp->isPointer=isPointer;
    temp->next=NULL;
    return temp;
}
void Install(char* name, Typetable* type, int size, int isArray, int rows, int cols,
             int isPointer, Paramstruct *paramlist, int isFunction){
    if(Lookup(name)!=NULL){
        printf("Multiple declaration of %s\n", name);
        exit(1);
    }
    Gsymbol *temp=(Gsymbol*)calloc(1, sizeof(Gsymbol));
    temp->name=strdup(name);
    temp->type=type;
    temp->size=size;
    temp->binding = isFunction ? -1 : binding;   // functions don't occupy data memory
    temp->paramlist=paramlist;
    temp->isFunction=isFunction;
    temp->body = NULL;
    temp->localCount = 0;
    temp->flabel = isFunction ? functionLabel++ : -1;
    temp->isArray=isArray;
    temp->rows=rows;
    temp->cols=cols;
    temp->isPointer=isPointer;
    temp->next=NULL;

    if(!isFunction){
        if(libMode){
            if(strcmp(name, "heap") != 0){
                printf("library code cannot declare global %s\n", name); exit(1);
            }
            temp->binding = 1024;
        } else binding += size;
    }

    if(Ghead==NULL) Ghead=temp;
    else {
        Gsymbol* ptr=Ghead;
        while(ptr->next) ptr=ptr->next;
        ptr->next=temp;
    }
}
void InstallParam(char* name, Typetable* type, int isPointer){
    if(LookupLocal(name)!=NULL){
        printf("Multiple declarations of %s\n", name);
        exit(1);
    }
    Lsymbol* temp=(Lsymbol*)calloc(1, sizeof(Lsymbol));
    temp->name=strdup(name);
    temp->type=type;
    paramCounter++;
    temp->binding=(-2 - paramCounter);
    temp->isPointer=isPointer;
    temp->next=NULL;
    if(Lhead==NULL)Lhead=temp;
    else {Lsymbol* p= Lhead;
    while(p->next)p=p->next;
    p->next=temp;
    }
}
void InstallLocalVar(char* name, Typetable* type, int isPointer){
    if(LookupLocal(name)!=NULL){
        printf("Multiple declaration of local variable %s\n", name);
        exit(1);
    }
    Lsymbol* temp=(Lsymbol*)calloc(1, sizeof(Lsymbol));
    temp->name = strdup(name);
    temp->type = type;
    localVarCounter++;
    temp->binding = localVarCounter;       // loc_1=+1, loc_2=+2, ...
    temp->isPointer=isPointer;
    temp->next = NULL;
    if(Lhead == NULL) Lhead = temp;
    else { Lsymbol* p=Lhead; while(p->next) p=p->next; p->next=temp; }
}
void InstallLocal(char *name, Typetable* type){
    if(LookupLocal(name) != NULL){
        printf("Multiple declaration of local variable %s\n", name);
        exit(1);
    }
    Lsymbol *temp = (Lsymbol*)calloc(1,sizeof(Lsymbol));
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
int paramMatchesArg(Paramstruct *p, tnode *a){
    return typesCompatible(p->type, a->type) && p->isPointer == a->isPointer;
}

tnode* buildCall(char *name, tnode *args){
    Gsymbol *entry = Lookup(name);
    if(!entry || !entry->isFunction){ printf("%s is not a declared function\n", name); exit(1); }
    Paramstruct *p = entry->paramlist; tnode *a = args;
    while(p && a){
        setAllocSize(a, p->type);
        if(!paramMatchesArg(p, a)){ printf("Argument type mismatch in %s\n", name); exit(1); }
        p = p->next; a = a->next;
    }
    if(p || a){ printf("Argument count mismatch in %s\n", name); exit(1); }
    tnode *call = createTree(0, entry->type, name, NODE_CALL, NULL, NULL, NULL);
    call->Gentry = entry; call->args = args;
    call->isPointer = entry->isPointer;       // you weren't setting this
    
    return call;
}

void printGsymbol(){
    Gsymbol* temp=Ghead;
    while(temp){
        printf("Name: %s\tType: %s\t", temp->name,
               temp->type->name);
        if(temp->isFunction){
            printf("FUNCTION\tflabel: F%d\tParams: (", temp->flabel);
            Paramstruct* p = temp->paramlist;
            while(p){
                printf("%s %s", p->type->name, p->name);
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
               temp->type->name,
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
        if(t->Lentry) return computeLocalAddress(t->Lentry->binding);
        int r=getReg();
        fprintf(target_file, "MOV R%d, %d\n", r, t->Gentry->binding);
        return r;
    }
    if(t->nodetype == NODE_FIELD){
        int r = codeGenExpr(t->left);          // value of the base = address of its heap block
        if(t->fieldOffset != 0)
            fprintf(target_file, "ADD R%d, %d\n", r, t->fieldOffset);
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
        if(iExpr->nodetype!=NODE_NUM && !libMode){
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
        if(jExpr->nodetype!=NODE_NUM && !libMode){
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
        if(t->right->nodetype!=NODE_NUM && !libMode){
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
void setAllocSize(tnode *rhs, Typetable *t){
    if(rhs && rhs->nodetype == NODE_ALLOC && isUserType(t)) rhs->val = t->size;
}
int codeGenCall(tnode *t){
    int live = regCount;
    for(int i = 0; i <= live; i++)
        fprintf(target_file, "PUSH R%d\n", i);

    int n = 0; tnode *args[64];
    for(tnode *a = t->args; a; a = a->next) args[n++] = a;

    for(int i = n-1; i >= 0; i--){
        int r = codeGenExpr(args[i]);
        fprintf(target_file, "PUSH R%d\n", r);
        freeReg(r);
    }
    fprintf(target_file, "PUSH R0\n");
    fprintf(target_file, "CALL F%d\n", t->Gentry->flabel);

    int ret = getReg();
    fprintf(target_file, "POP R%d\n", ret);
    int tmp = getReg();
    for(int i = 0; i < n; i++)
        fprintf(target_file, "POP R%d\n", tmp);
    freeReg(tmp);
    for(int i = live; i >= 0; i--)
        fprintf(target_file, "POP R%d\n", i);
    return ret;
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
            r1 = getReg();
            if(t->Lentry != NULL) emitLoadLocal(r1, t->Lentry->binding);
            else fprintf(target_file, "MOV R%d, [%d]\n", r1, getAddress(t));
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
        {   int addr=codeGenAddr(t);
            //int r= getReg();
            fprintf(target_file, "MOV R%d, [R%d]\n", addr, addr);
            //freeReg(addr);
            return addr;
        }
        case NODE_ADDR:
            return codeGenAddr(t->left);
        case NODE_DEREF:
        {
            int r=codeGenExpr(t->left);
            fprintf(target_file, "MOV R%d, [R%d]\n", r, r);
            return r;
        }
        case NODE_CALL:
            return codeGenCall(t);
        case NODE_NULL:
            r1 = getReg();
            fprintf(target_file, "MOV R%d, 0\n", r1);
            return r1;
        case NODE_ALLOC:
            return emitLibCall("Alloc", -1, t->val > 0 ? t->val : 8);
        case NODE_INIT:
            return emitLibCall("Heapset", -1, 0);
        case NODE_FREE:
        {
            int r = codeGenExpr(t->left);
            int res = emitLibCall("Free", r, 0);
            fprintf(target_file, "MOV R%d, R%d\n", r, res);   // result goes in the lower register
            freeReg(res);
            return r;
        }
        case NODE_FIELD:
        {
            int addr = codeGenAddr(t);
            fprintf(target_file, "MOV R%d, [R%d]\n", addr, addr);
            return addr;
        }
        
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
                if(t->left->Lentry != NULL) emitStoreLocal(r, t->left->Lentry->binding);
                else fprintf(target_file, "MOV [%d], R%d\n", getAddress(t->left), r);
                freeReg(r);
            }
            else if(t->left->nodetype == NODE_FIELD){
                int addr = codeGenAddr(t->left);
                int r = codeGenExpr(t->right);
                fprintf(target_file, "MOV [R%d], R%d\n", addr, r);
                freeReg(r); freeReg(addr);
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
            {
                int addr = codeGenAddr(t->left);   // handles global, local and array targets
                int tmp  = getReg();               // scratch register, so nothing live is clobbered

                fprintf(target_file, "MOV R%d, \"Read\"\n", tmp);
                fprintf(target_file, "PUSH R%d\n", tmp);
                fprintf(target_file, "MOV R%d, -1\n", tmp);
                fprintf(target_file, "PUSH R%d\n", tmp);
                fprintf(target_file, "PUSH R%d\n", addr);      // address to read into
                fprintf(target_file, "MOV R%d, 0\n", tmp);
                fprintf(target_file, "PUSH R%d\n", tmp);
                fprintf(target_file, "PUSH R%d\n", tmp);
                fprintf(target_file, "CALL 0\n");
                for(int i = 0; i < 5; i++)
                    fprintf(target_file, "POP R%d\n", tmp);

                freeReg(tmp);
                freeReg(addr);
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
        case NODE_RETURN:
        {
            
            int r = codeGenExpr(t->left);
            emitStoreLocal(r, -2);
            freeReg(r);
            
            if(currentFunction->localCount > 0)
                fprintf(target_file, "SUB SP, %d\n", currentFunction->localCount);
            fprintf(target_file, "POP BP\n");
            fprintf(target_file, "RET\n");
            break;
        }
        case NODE_CALL:
        {
            int r = codeGenExpr(t);   // performs the call, argument pushes, everything
            freeReg(r);                // discard the return value
            break;
        }
        case NODE_INIT:
        case NODE_FREE:
        {
            int r = codeGenExpr(t);
            freeReg(r);
            break;
        }
        
    }
}
// Calls a library routine. Arg 1 is register argReg if >= 0, else the constant imm.
// Returns the register holding the result (the first free register on entry).
int emitLibCall(char *code, int argReg, int imm){
    int live = regCount;
    for(int i = 0; i <= live; i++)
        fprintf(target_file, "PUSH R%d\n", i);               // save registers in use

    int t = getReg();
    fprintf(target_file, "MOV R%d, \"%s\"\n", t, code);
    fprintf(target_file, "PUSH R%d\n", t);                   // function code
    if(argReg >= 0) fprintf(target_file, "PUSH R%d\n", argReg);
    else { fprintf(target_file, "MOV R%d, %d\n", t, imm);
           fprintf(target_file, "PUSH R%d\n", t); }          // arg 1
    fprintf(target_file, "MOV R%d, 0\n", t);
    fprintf(target_file, "PUSH R%d\n", t);                   // arg 2
    fprintf(target_file, "PUSH R%d\n", t);                   // arg 3
    fprintf(target_file, "PUSH R%d\n", t);                   // return slot
    fprintf(target_file, "CALL 0\n");
    fprintf(target_file, "POP R%d\n", t);                    // return value
    int s = getReg();
    for(int i = 0; i < 4; i++)
        fprintf(target_file, "POP R%d\n", s);                // discard code + 3 args
    freeReg(s);
    for(int i = live; i >= 0; i--)
        fprintf(target_file, "POP R%d\n", i);                // restore registers
    return t;
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
tnode* createTree(int val, Typetable* type, char* varname, int nodetype, tnode* left, tnode* middle, tnode* right){
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
    temp->fieldOffset = -1;
    temp->args = NULL;
    temp->next = NULL;
    if(nodetype==NODE_PLUS || nodetype==NODE_MINUS || nodetype==NODE_MUL || nodetype==NODE_DIV){
        if(left->type !=tint || right->type !=tint){
            printf("Type Mismatch\n");
            exit(1);
        }
        temp->type=tint;
    }
    else if(nodetype == NODE_EQ || nodetype == NODE_NE){
        int ok = (left->type == tint && right->type == tint)
            || (left->type == tstr && right->type == tstr)
            || ((isUserType(left->type)  || left->type  == tnull) &&
                (isUserType(right->type) || right->type == tnull) &&
                (left->type == right->type || left->type == tnull || right->type == tnull));
        if(!ok){ printf("Type Mismatch\n"); exit(1); }
        temp->type = tbool;
    }
    else if(nodetype== NODE_LT || nodetype== NODE_GT || nodetype== NODE_LE || nodetype== NODE_GE){
        if(left->type!=tint || right->type != tint){
            printf("Type Mismatch\n");
            exit(1);
        }
        temp->type=tbool;
    }
    else if (nodetype==NODE_ASSIGN){
        if(!typesCompatible(left->type, right->type) || left->isPointer != right->isPointer){
            printf("Type Mismatch\n");
            exit(1);
        }
        temp->type = tvoid;
    }
    else if(nodetype==NODE_IF){
        if(left->type != tbool){
            printf("Type Mismatch\n");
            exit(1);
        }
        temp->type=tvoid;
    }
    else if(nodetype==NODE_WHILE){
        if(left->type!=tbool){
            printf("Type Mismatch\n");
            exit(1);
        }
        temp->type=tvoid;
    }
    else if(nodetype== NODE_WRITE){
        if(left->type!=tint){
            printf("Type Mismatch\n");
            exit(1);
        }
        temp->type=tvoid;
    }
    else if(nodetype== NODE_REPEAT || nodetype==NODE_DOWHILE){
        if(right->type!=tbool){
            printf("Type Mismatch\n");
            exit(1);
        }
        temp->type=tvoid;
    }
    else if(nodetype==NODE_ARRAY){
        if(right->type != tint){
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
            printf("NUM(%d) [type=%s]\n", t->val, t->type->name);
            break;

        case NODE_ID:
            if(t->Lentry != NULL){
                printf("ID(%s) [type=%s, pointer=%d, local binding=%d]\n",
                    t->varname,
                    t->type->name,
                    t->isPointer,
                    t->Lentry->binding);
            }
            else if(t->Gentry != NULL){
                printf("ID(%s) [type=%s, pointer=%d, global binding=%d]\n",
                    t->varname,
                    t->type->name,
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
            printf("ARRAY [type %s]\n", t->type->name);
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
void setupFunction(char *name, Typetable *returnType, int returnIsPointer, Paramstruct *params){
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
    if(returnType != currentFunction->type || returnIsPointer != currentFunction->isPointer){
        printf("Return type mismatch for function %s\n", name);
        exit(1);
    }

    /* Check parameters */
    Paramstruct *decl = currentFunction->paramlist;
    Paramstruct *def = params;

    while(decl != NULL && def != NULL){
        if(decl->type != def->type || decl->isPointer != def->isPointer){
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

    if(decl != NULL || def != NULL){
        printf("Parameter count mismatch in function %s\n", name);
        exit(1);
    }

    if(strcmp(name, "main") == 0){
        if(returnType != tint){
            printf("main must have return type int\n");
            exit(1);
        }
        if(params != NULL){
            printf("main cannot have parameters\n");
            exit(1);
        }
    }

    /* Create local table */
    Lhead = NULL; paramCounter = 0; localVarCounter = 0;
    for(Paramstruct *p = params; p; p = p->next)
        InstallParam(p->name, p->type, p->isPointer);
}
// void emitLoadLocal(int reg, int offset){
//     if(offset >= 0) fprintf(target_file, "MOV R%d, [BP+%d]\n", reg, offset);
//     else             fprintf(target_file, "MOV R%d, [BP%d]\n", reg, offset); // prints "[BP-3]"
// }
// void emitStoreLocal(int reg, int offset){
//     if(offset >= 0) fprintf(target_file, "MOV [BP+%d], R%d\n", offset, reg);
//     else             fprintf(target_file, "MOV [BP%d], R%d\n", offset, reg);
// }
void emitLoadLocal(int reg, int offset){
    int a = computeLocalAddress(offset);   // a = BP + offset, in a register
    fprintf(target_file, "MOV R%d, [R%d]\n", reg, a);
    freeReg(a);
}
void emitStoreLocal(int reg, int offset){
    int a = computeLocalAddress(offset);
    fprintf(target_file, "MOV [R%d], R%d\n", a, reg);
    freeReg(a);
}
int computeLocalAddress(int offset){
    int r = getReg();
    fprintf(target_file, "MOV R%d, BP\n", r);
    if(offset >= 0) fprintf(target_file, "ADD R%d, %d\n", r, offset);
    else fprintf(target_file, "SUB R%d, %d\n", r, -offset);
    return r;
}
void resolveID(tnode *node){
    Lsymbol *lentry = LookupLocal(node->varname);
    if(lentry != NULL){
        node->Lentry = lentry;
        node->type = lentry->type;
        node->isPointer = lentry->isPointer;
        return;
    }
    Gsymbol *gentry = Lookup(node->varname);
    if(gentry == NULL){ printf("Variable %s not declared\n", node->varname); exit(1); }
    if(gentry->isFunction){ printf("%s is a function, not a variable\n", node->varname); exit(1); }
    node->Gentry = gentry;
    node->type = gentry->type;
    node->isPointer = gentry->isPointer;
}
static void writeStub(char *code, char *fname, int hasArg, int nextLabel){
    Gsymbol *g = Lookup(fname);
    if(!g || !g->isFunction || !g->body){
        printf("library function %s is not defined\n", fname); exit(1);
    }
    fprintf(target_file, "MOV R1, SP\nMOV R2, 5\nSUB R1, R2\n");
    fprintf(target_file, "MOV R2, \"%s\"\nMOV R1, [R1]\nEQ R1, R2\nJZ R1, L%d\n", code, nextLabel);
    if(hasArg)
        fprintf(target_file, "MOV R1, SP\nMOV R2, 4\nSUB R1, R2\nMOV R1, [R1]\nPUSH R1\n");
    fprintf(target_file, "PUSH R0\nCALL F%d\nPOP R1\n", g->flabel);
    if(hasArg) fprintf(target_file, "POP R2\n");
    fprintf(target_file, "MOV R2, SP\nMOV R3, 1\nSUB R2, R3\nMOV [R2], R1\nRET\nL%d:\n", nextLabel);
}

void writeLibrary(){
    fprintf(target_file, "L9000:\n");
    int a = getLabel(), b = getLabel(), c = getLabel();
    writeStub("Heapset", "buddyInit",  0, a);
    writeStub("Alloc",   "buddyAlloc", 1, b);
    writeStub("Free",    "buddyFree",  1, c);
    fprintf(target_file, "RET\n");
    for(Gsymbol *g = Ghead; g; g = g->next){
        if(!g->isFunction || !g->body) continue;
        currentFunction = g;
        fprintf(target_file, "F%d:\n", g->flabel);
        fprintf(target_file, "PUSH BP\nMOV BP, SP\n");
        if(g->localCount) fprintf(target_file, "ADD SP, %d\n", g->localCount);
        codeGen(g->body);
    }
    writeArrayErrorHandler();
}
void yyerror(char* s){
    printf("%s\n", s);
}
