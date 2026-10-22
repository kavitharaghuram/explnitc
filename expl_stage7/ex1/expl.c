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

Typetable *tclass;                       // sentinel type for class variables
Classtable *CHead = NULL, *Cptr = NULL;  // Cptr = class currently being defined
Classtable *lastClass = NULL;            // set by TypeName in the parser
Classtable *currentCtype = NULL;         // class of the global variable being declared
Memberfunclist *currentMethod = NULL;    // method whose body is being parsed
int classCount = 0;

Classtable* CLookup(char *name){
    for(Classtable *c = CHead; c; c = c->next)
        if(!strcmp(c->name, name)) return c;
    return NULL;
}
Classtable* CInstall(char *name, char *parent){
    if(CLookup(name) || TLookup(name)){
        printf("Multiple declaration of class %s\n", name); exit(1);
    }
    if(parent != NULL){                  // Stage 8 will inherit fields and methods here
        printf("Class extension is not supported yet\n"); exit(1);
    }
    Classtable *c = calloc(1, sizeof(Classtable));
    c->name = strdup(name);
    c->parentPtr = NULL;
    c->classIndex = classCount++;
    if(!CHead) CHead = c;
    else { Classtable *p = CHead; while(p->next) p = p->next; p->next = c; }
    return c;
}
Fieldlist* Class_Flookup(Classtable *c, char *name){
    for(Fieldlist *f = c->memberField; f; f = f->next)
        if(!strcmp(f->name, name)) return f;
    return NULL;
}
Memberfunclist* Class_Mlookup(Classtable *c, char *name){
    for(Memberfunclist *m = c->vFuncPtr; m; m = m->next)
        if(!strcmp(m->name, name)) return m;
    return NULL;
}

void Class_Finstall(Classtable *c, Typetable *type, Classtable *ctype, char *name){
    if(c->methodCount > 0){
        printf("Field %s must be declared before the methods of class %s\n", name, c->name); exit(1);
    }
    if(c->fieldCount >= 8){
        printf("Class %s has more than 8 member fields\n", c->name); exit(1);
    }
    if(Class_Flookup(c, name)){
        printf("Duplicate field %s in class %s\n", name, c->name); exit(1);
    }
    Fieldlist *f = calloc(1, sizeof(Fieldlist));
    f->name = strdup(name);
    f->type = type;                       // tclass if the field is of a class type
    f->ctype = ctype;                     // the class itself, or NULL
    f->fieldIndex = c->fieldCount++;
    if(!c->memberField) c->memberField = f;
    else { Fieldlist *p = c->memberField; while(p->next) p = p->next; p->next = f; }
}

void Class_Minstall(Classtable *c, char *name, Typetable *type, int isPointer, Paramstruct *params){
    if(c->methodCount >= 8){
        printf("Class %s has more than 8 methods\n", c->name); exit(1);
    }
    if(Class_Mlookup(c, name)){
        printf("Method %s declared twice in class %s (no overloading)\n", name, c->name); exit(1);
    }
    if(Class_Flookup(c, name)){
        printf("%s is already a field of class %s\n", name, c->name); exit(1);
    }
    Memberfunclist *m = calloc(1, sizeof(Memberfunclist));
    m->name = strdup(name);
    m->type = type;
    m->isPointer = isPointer;
    m->paramlist = params;
    m->funcposition = c->methodCount++;
    m->flabel = functionLabel++;          // shares the counter with global functions → unique F<n>
    if(!c->vFuncPtr) c->vFuncPtr = m;
    else { Memberfunclist *p = c->vFuncPtr; while(p->next) p = p->next; p->next = m; }
}
int isSubclass(Classtable *sub, Classtable *super){
    for(Classtable *c = sub; c; c = c->parentPtr) if(c == super) return 1;
    return 0;
}
/* src NULL means the NULL literal. In Stage 8 a child object fits in a parent variable. */
int classCompatible(Classtable *dst, Classtable *src){
    return src == NULL || isSubclass(src, dst);
}
void rejectClass(Typetable *t, char *context){
    if(t == tclass){
        printf("A class cannot be used as a %s\n", context); exit(1);
    }
}
/* Methods may not touch globals (spec 6a). Everything else keeps using Lookup(). */
Gsymbol* LookupVar(char *name){
    if(Cptr != NULL){
        printf("'%s' not found: methods can only use locals, parameters and self.<field>\n", name);
        exit(1);
    }
    return Lookup(name);
}
void setupMethod(char *name, Typetable *rt, int rptr, Paramstruct *params){
    rejectClass(rt, "method return type");
    Memberfunclist *m = Class_Mlookup(Cptr, name);
    if(!m){ printf("Method %s is not declared in class %s\n", name, Cptr->name); exit(1); }
    if(m->body){ printf("Method %s defined twice\n", name); exit(1); }
    if(rt != m->type || rptr != m->isPointer){
        printf("Return type mismatch for method %s\n", name); exit(1);
    }
    Paramstruct *d = m->paramlist, *p = params;
    while(d && p){
        if(d->type != p->type || d->isPointer != p->isPointer || d->ctype != p->ctype || strcmp(d->name, p->name)){
            printf("Parameter mismatch in method %s\n", name); exit(1);
        }
        d = d->next; p = p->next;
    }
    if(d || p){ printf("Parameter count mismatch in method %s\n", name); exit(1); }

        currentMethod = m;
    Lhead = NULL; localVarCounter = 0;
    paramCounter = 0;                                  // was 1: now back to the Stage 6 value
    for(Paramstruct *q = params; q; q = q->next)
        InstallParam(q->name, q->type, q->isPointer, q->ctype);
    InstallParam("self", tclass, 0, Cptr);                   // implicit argument, pushed first by the caller
    m->selfBinding = LookupLocal("self")->binding;     // -(3 + number of params)
}
void finishMethod(tnode *body){
    printf("Method definition: %s\n", currentMethod->name);
    printLsymbol();
    printTree(body, 0);
    currentMethod->body = body;
    currentMethod->localCount = localVarCounter;
    currentMethod = NULL;
}
void checkMethodsDefined(Classtable *c){
    for(Memberfunclist *m = c->vFuncPtr; m; m = m->next)
        if(!m->body){
            printf("Method %s of class %s is declared but not defined\n", m->name, c->name); exit(1);
        }
}
void checkReturn(tnode *e){
    Typetable *rt; int rp; char *fn;
    if(currentMethod){ rt = currentMethod->type; rp = currentMethod->isPointer; fn = currentMethod->name; }
    else if(currentFunction){ rt = currentFunction->type; rp = currentFunction->isPointer; fn = currentFunction->name; }
    else { printf("return statement outside a function\n"); exit(1); }
    if(!typesCompatible(rt, e->type) || rp != e->isPointer){
        printf("Return type mismatch in function %s\n", fn); exit(1);
    }
}
tnode* makeSelf(){
    if(Cptr == NULL){ printf("'self' used outside a class\n"); exit(1); }
    tnode *n = createTree(0, tclass, NULL, NODE_SELF, NULL, NULL, NULL);
    n->ctype = Cptr;
    return n;
}

tnode* buildSelfField(char *fieldName){
    if(Cptr == NULL){ printf("'self' used outside a class\n"); exit(1); }
    Fieldlist *f = Class_Flookup(Cptr, fieldName);
    if(!f){ printf("Class %s has no field %s\n", Cptr->name, fieldName); exit(1); }
    tnode *n = createTree(0, f->type, strdup(fieldName), NODE_SELFFIELD, NULL, NULL, NULL);
    n->fieldOffset = f->fieldIndex;
    n->ctype = f->ctype;                  // non-NULL means the field is itself an object
    return n;
}

tnode* buildMethodCall(tnode *base, char *mname, tnode *args){
    Classtable *c = NULL;
    if(base->nodetype == NODE_SELF)            c = base->ctype;              // self.m()
    else if(base->nodetype == NODE_SELFFIELD){                                // self.f.m()
        c = base->ctype;
        if(!c){ printf("Field %s is not of a class type\n", base->varname); exit(1); }
    }
    else if(base->nodetype == NODE_ID){
        if(Cptr != NULL){
            printf("Methods may only call methods of self or of class-typed fields\n"); exit(1);
        }                                       // var.m()
        if(base->type != tclass){ printf("%s is not a class variable\n", base->varname); exit(1); }
        c = base->ctype;
    }
    else { printf("Invalid target for a method call\n"); exit(1); }

    Memberfunclist *m = Class_Mlookup(c, mname);
    if(!m){ printf("Class %s has no method %s\n", c->name, mname); exit(1); }

    Paramstruct *p = m->paramlist; tnode *a = args;
    while(p && a){
        setAllocSize(a, p->type);
        if(!paramMatchesArg(p, a)){ printf("Argument type mismatch in call to %s\n", mname); exit(1); }
        p = p->next; a = a->next;
    }
    if(p || a){ printf("Argument count mismatch in call to %s\n", mname); exit(1); }

    tnode *call = createTree(0, m->type, strdup(mname), NODE_METHODCALL, base, NULL, NULL);
    call->method = m;
    call->args = args;
    call->isPointer = m->isPointer;
    return call;
}

void printClassTable(){
    for(Classtable *c = CHead; c; c = c->next){
        printf("Class %s (index %d, fields %d, methods %d)\n", c->name, c->classIndex, c->fieldCount, c->methodCount);
        for(Fieldlist *f = c->memberField; f; f = f->next)
            printf("  field %d: %s %s\n", f->fieldIndex, f->ctype ? f->ctype->name : f->type->name, f->name);
        for(Memberfunclist *m = c->vFuncPtr; m; m = m->next)
            printf("  method %d: %s %s  label F%d\n", m->funcposition, m->type->name, m->name, m->flabel);
    }
}
tnode* buildFieldAccess(tnode *base, char *fieldName){
    if(base->nodetype == NODE_SELFFIELD){
        printf("self.%s.%s is not permitted: only methods may be used through a member\n", base->varname, fieldName);
        exit(1);
    }
    if(base->type == tclass){
        printf("Member fields of a class are private; use a method\n"); exit(1);
    }
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
    tclass = TInstall("class", 0, NULL);
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
    return dst == src || ((isUserType(dst) || dst == tclass) && src == tnull);
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
Paramstruct* createParam(char* name,Typetable* type, int isPointer, Classtable *ctype){
    Paramstruct *temp=(Paramstruct*)calloc(1, sizeof(Paramstruct));
    temp->name=name;
    temp->type=type;
    temp->isPointer=isPointer;
    temp->ctype=ctype;
    temp->next=NULL;
    return temp;
}
void Install(char* name, Typetable* type, int size, int isArray, int rows, int cols,
             int isPointer, Paramstruct *paramlist, int isFunction){
    if(Lookup(name)!=NULL){
        printf("Multiple declaration of %s\n", name);
        exit(1);
    }
    if(type == tclass && (isFunction || isArray || isPointer)){
        printf("%s: a class variable cannot be an array, pointer or function result\n", name); exit(1);
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
    temp->ctype = (type == tclass && !isFunction) ? currentCtype : NULL;
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
void InstallParam(char* name, Typetable* type, int isPointer, Classtable* ctype){
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
    temp->ctype=ctype;
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
    return typesCompatible(p->type, a->type) && p->isPointer == a->isPointer
        && (p->type != tclass || classCompatible(p->ctype, a->ctype));
}

tnode* buildCall(char *name, tnode *args){
    if(Cptr){ printf("Methods may only call methods of their own class or of class-typed fields\n"); exit(1); }
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
    if(t->nodetype == NODE_SELFFIELD){
        int r = getReg();
        emitLoadLocal(r, currentMethod->selfBinding);   // r = address of the object's heap block
        if(t->fieldOffset != 0)
            fprintf(target_file, "ADD R%d, %d\n", r, t->fieldOffset);
        return r;                                       // r = address of the field
    }
    
    return -1;
}
void setAllocSize(tnode *rhs, Typetable *t){
    if(rhs && rhs->nodetype == NODE_ALLOC && isUserType(t)) rhs->val = t->size;
}
int codeGenMethodCall(tnode *t){
    int live = regCount;
    for(int i = 0; i <= live; i++)
        fprintf(target_file, "PUSH R%d\n", i);            // save registers in use

    int rs = codeGenExpr(t->left);                        // object pointer (var, self, or self.field)
    fprintf(target_file, "PUSH R%d\n", rs);               // 'self' goes first (convention)
    freeReg(rs);

    int n = 0; tnode *args[64];
    for(tnode *a = t->args; a; a = a->next) args[n++] = a;
    for(int i = n-1; i >= 0; i--){                        // then arguments, last to first
        int r = codeGenExpr(args[i]);
        fprintf(target_file, "PUSH R%d\n", r);
        freeReg(r);
    }
    fprintf(target_file, "PUSH R0\n");                    // return slot
    fprintf(target_file, "CALL F%d\n", t->method->flabel);

    int ret = getReg();
    fprintf(target_file, "POP R%d\n", ret);               // return value
    int tmp = getReg();
    for(int i = 0; i < n + 1; i++)                        // n args + self
        fprintf(target_file, "POP R%d\n", tmp);
    freeReg(tmp);
    for(int i = live; i >= 0; i--)
        fprintf(target_file, "POP R%d\n", i);             // restore registers
    return ret;
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
        case NODE_SELFFIELD:
        {
            int addr = codeGenAddr(t);
            fprintf(target_file, "MOV R%d, [R%d]\n", addr, addr);
            return addr;
        }
        case NODE_SELF:
            r1 = getReg();
            emitLoadLocal(r1, currentMethod->selfBinding);   // value of self = object pointer
            return r1;
        case NODE_NEW:
            return emitLibCall("Alloc", -1, 8);              // 8 words, like user-defined types
        case NODE_METHODCALL:
            return codeGenMethodCall(t);
        
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
            else if(t->left->nodetype == NODE_FIELD || t->left->nodetype == NODE_SELFFIELD){
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
            int lc = currentMethod ? currentMethod->localCount : currentFunction->localCount;
            if(lc > 0)
                fprintf(target_file, "SUB SP, %d\n", lc);
            fprintf(target_file, "POP BP\n");
            fprintf(target_file, "RET\n");
            break;
        }
        
        case NODE_INIT:
        case NODE_FREE:
        {
            int r = codeGenExpr(t);
            freeReg(r);
            break;
        }
        case NODE_CALL:
        case NODE_METHODCALL:
        {
            int r = codeGenExpr(t);
            freeReg(r);
            break;
        }
        case NODE_DELETE:
        {
            int r   = codeGenExpr(t->left);               // object pointer
            int res = emitLibCall("Free", r, 0);
            freeReg(res);
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
    temp->ctype = NULL;
    temp->method = NULL;
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
        if(!typesCompatible(left->type, right->type) || left->isPointer != right->isPointer || (left->type == tclass && !classCompatible(left->ctype, right->ctype))){
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
void emitMethods(){
    currentFunction = NULL;
    for(Classtable *c = CHead; c; c = c->next)
        for(Memberfunclist *m = c->vFuncPtr; m; m = m->next){
            currentMethod = m;                            // codegen of self/return reads this
            fprintf(target_file, "F%d:\n", m->flabel);
            fprintf(target_file, "PUSH BP\nMOV BP, SP\n");
            if(m->localCount) fprintf(target_file, "ADD SP, %d\n", m->localCount);
            for(int i = 1; i <= m->localCount; i++)
                fprintf(target_file, "MOV R0, BP\nADD R0, %d\nMOV R1, 0\nMOV [R0], R1\n", i);
            codeGen(m->body);
        }
    currentMethod = NULL;
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
                case NODE_RETURN: printf("RETURN\n"); break;
        case NODE_NULL:   printf("NULL\n");   break;
        case NODE_ALLOC:  printf("ALLOC\n");  break;
        case NODE_FREE:   printf("FREE\n");   break;
        case NODE_INIT:   printf("INITIALIZE\n"); break;
        case NODE_FIELD:  printf("FIELD[%d]\n", t->fieldOffset); break;
        case NODE_SELF:       printf("SELF\n"); break;
        case NODE_SELFFIELD:  printf("SELF.%s\n", t->varname); break;
        case NODE_METHODCALL: printf("METHODCALL(%s)\n", t->varname); break;
        case NODE_NEW:        printf("NEW(%s)\n", t->ctype->name); break;
        case NODE_DELETE:     printf("DELETE\n"); break;

        default:
            printf("UNKNOWN NODE\n");
    }

    printTree(t->left, level + 1);
    printTree(t->middle, level + 1);
    printTree(t->right, level + 1);

        if(t->nodetype == NODE_CALL || t->nodetype == NODE_METHODCALL){
        tnode *a = t->args;
        while(a != NULL){
            printTree(a, level + 1);
            a = a->next;
        }
    }
}
void setupFunction(char *name, Typetable *returnType, int returnIsPointer, Paramstruct *params){
    rejectClass(returnType, "return type");
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
        if(decl->type != def->type || decl->isPointer != def->isPointer || decl->ctype != def->ctype){
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
        InstallParam(p->name, p->type, p->isPointer, p->ctype);
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
        node->ctype=lentry->ctype;
        return;
    }
    Gsymbol *gentry = LookupVar(node->varname);
    if(gentry == NULL){ printf("Variable %s not declared\n", node->varname); exit(1); }
    if(gentry->isFunction){ printf("%s is a function, not a variable\n", node->varname); exit(1); }
    node->Gentry = gentry;
    node->type = gentry->type;
    node->isPointer = gentry->isPointer;
    node->ctype = gentry->ctype;  
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
