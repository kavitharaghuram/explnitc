#ifndef EXPL_H
#define EXPL_H

#include<stdio.h>
#include<stdlib.h>
#include<string.h>

#define TYPE_NONE -1
#define TYPE_BOOL 0
#define TYPE_INT 1
#define TYPE_STR 2

#define NODE_NUM        1
#define NODE_ID         2
#define NODE_PLUS       3
#define NODE_MINUS      4
#define NODE_MUL        5
#define NODE_DIV        6
#define NODE_ASSIGN     7
#define NODE_READ       8
#define NODE_WRITE      9
#define NODE_CONNECT   10

#define NODE_LT 11
#define NODE_GT 12
#define NODE_LE 13
#define NODE_GE 14
#define NODE_EQ 15
#define NODE_NE 16

#define NODE_IF 17
#define NODE_WHILE 18
#define NODE_BREAK 19
#define NODE_CONTINUE 20
#define NODE_REPEAT 21
#define NODE_DOWHILE 22
#define NODE_ARRAY 23
#define NODE_ADDR 24
#define NODE_DEREF 25
#define NODE_CALL 26
#define NODE_RETURN 27   // pick an unused number
#define NODE_FIELD 28
#define NODE_NULL 29
#define NODE_ALLOC 30
#define NODE_FREE  31
#define NODE_INIT  32
#define NODE_SELF       33   // the 'self' object
#define NODE_SELFFIELD  34   // self.field
#define NODE_METHODCALL 35   // obj.method(args)
#define NODE_NEW        36   // new(ClassName)
#define NODE_DELETE     37   // delete(x)
struct Classtable;                       // forward declaration (put above Fieldlist)

typedef struct Fieldlist{
    char *name;
    int fieldIndex;
    struct Typetable *type;
    struct Classtable *ctype;            // NEW: set if the field is of a class type
    struct Fieldlist *next;
} Fieldlist;

typedef struct Typetable{
    char *name;
    int size;                       // number of fields (0 for built-ins)
    Fieldlist *fields;              // NULL for built-in types
    struct Typetable *next;
} Typetable;

extern Typetable *tint, *tstr, *tbool, *tvoid, *tnull;
void TypeTableCreate();
Typetable* TInstall(char *name, int size, Fieldlist *fields);
Typetable* TLookup(char *name);
Fieldlist* FLookup(Typetable *t, char *fieldName);
int isUserType(Typetable *t);
int typesCompatible(Typetable *dst, Typetable *src);
int emitLibCall(char *code, int argReg, int imm);
typedef struct Paramstruct{
    char* name;
    Typetable *type;
    int isPointer;
    struct Classtable *ctype;
    struct Paramstruct *next;
} Paramstruct;
typedef struct Memberfunclist{
    char *name;
    Typetable *type;                 // return type
    int isPointer;                   // returns a pointer?
    Paramstruct *paramlist;
    int funcposition;                // 0 for first method, 1 for next...
    int flabel;                      // label of the method's code
    int selfBinding;         // BP-relative slot where the caller pushes 'self'
    struct Classtable *owner;        // class whose code this entry runs (parent's, if inherited)
    struct tnode *body;              // filled when the method is defined
    int localCount;
    struct Memberfunclist *next;
} Memberfunclist;

typedef struct Classtable{
    char *name;
    Fieldlist *memberField;
    Memberfunclist *vFuncPtr;
    struct Classtable *parentPtr;    // always NULL this stage
    int classIndex;
    int fieldCount;
    int methodCount;
    struct Classtable *next;
} Classtable;
typedef struct Lsymbol{
    char* name;
    Typetable* type;
    int binding;
    int isPointer;
    struct Classtable *ctype; 
    struct Lsymbol *next;
} Lsymbol;

typedef struct Gsymbol{
    char* name;
    Typetable* type;
    int size;
    int binding;
    Paramstruct *paramlist;
    int flabel;
    int isArray;
    int rows;
    int cols;
    int isPointer;
    int isFunction;
    int localCount;
    struct Classtable *ctype;
    struct Gsymbol* next;
    struct tnode* body;
} Gsymbol;

typedef struct tnode{
    int val; //value of number for NUM nodes
    int nodetype; //info about non-leaf nodes
    Typetable* type; //type of variable
    char *varname; //name of variables for id
    int isPointer;
    struct Gsymbol* Gentry; 
    struct Lsymbol *Lentry;
    int fieldOffset;
    struct Classtable *ctype;
    struct Memberfunclist *method;
    struct tnode *left;
    struct tnode* middle;
    struct tnode *right;
    struct tnode *args;
    struct tnode *next;
} tnode;



tnode* buildFieldAccess(tnode *idNode, char *fieldName);
/* Global variables */
extern Gsymbol *Ghead;
extern int binding;
void setAllocSize(tnode *rhs, Typetable *t);
extern int breakStack[100];
extern int continueStack[100];
extern int loopTop;
extern int functionLabel;

extern int libMode;
void writeLibrary();
void setAllocSize(tnode *rhs, Typetable *t);

extern int arrayErrorLabel;
extern FILE *target_file;

extern Gsymbol *currentFunction;
extern Lsymbol *Lhead;
extern int localBinding;
extern int localVarCounter;

/* Symbol table functions */
Gsymbol* Lookup(char* name);
void Install(char* name, Typetable* type, int size, int isArray,
             int rows, int cols, int isPointer, Paramstruct* paramlist, int isFunction);
void printGsymbol();


/* Register and label functions */
int getReg();
void freeReg(int reg);
int getLabel();


/* Loop functions */
void pushLoop(int breakLabel, int continueLabel);
void popLoop();


/* Code generation functions */
int getAddress(tnode* t);
int codeGenAddr(tnode* t);
int codeGenExpr(tnode* t);
void codeGen(tnode* t);


/* XSM output functions */
void writeHeader();
void writeExit();
void writeArrayErrorHandler();


/* AST functions */
tnode* createTree(int val, Typetable* type, char* varname, int nodetype,
                  tnode* left, tnode* middle, tnode* right);
void printTree(tnode* t, int level);


Paramstruct* createParam(char *name, Typetable* type, int isPointer, Classtable *ctype);
void InstallParam(char* name, Typetable *type, int isPointer, Classtable *ctype);

Lsymbol* LookupLocal(char *name);
void InstallLocal(char *name, Typetable* type);
void printLsymbol();

void setupFunction(char *name, Typetable *returnType, int returnIsPointer, Paramstruct *params);
tnode* buildCall(char *name, tnode *args);
int  paramMatchesArg(Paramstruct *p, tnode *a);
Gsymbol* LookupGlobal(char *name);
void resolveID(tnode *node);
void InstallLocalVar(char* name, Typetable *type, int isPointer, Classtable *ctype);
int computeLocalAddress(int offset);
int codeGenCall(tnode *t);
/* Error handling */
void yyerror(char* s);
void emitLoadLocal(int reg, int offset);
void emitStoreLocal(int reg, int offset);
extern Typetable *tclass;
extern Classtable *Cptr, *lastClass, *currentCtype;
extern Memberfunclist *currentMethod;

Classtable* CInstall(char *name, char *parent);
Classtable* CLookup(char *name);
void Class_Finstall(Classtable *c, Typetable *type, Classtable *ctype, char *name);
void Class_Minstall(Classtable *c, char *name, Typetable *type, int isPointer, Paramstruct *params);
Memberfunclist* Class_Mlookup(Classtable *c, char *name);
Fieldlist* Class_Flookup(Classtable *c, char *name);
int  classCompatible(Classtable *dst, Classtable *src);
void rejectClass(Typetable *t, char *context);
Gsymbol* LookupVar(char *name);
tnode* makeSelf();
tnode* buildSelfField(char *fieldName);
tnode* buildMethodCall(tnode *base, char *mname, tnode *args);
void setupMethod(char *name, Typetable *rt, int rptr, Paramstruct *params);
void finishMethod(tnode *body);
void checkMethodsDefined(Classtable *c);
void checkReturn(tnode *e);
void printClassTable();
int codeGenMethodCall(tnode *t);
void emitMethods();
extern int classCount;
void emitVFT();
#endif