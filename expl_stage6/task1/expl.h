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
typedef struct Fieldlist{
    char *name;
    int fieldIndex;                 // 0-based position in the type
    struct Typetable *type;         // pointer to the field's type entry
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

typedef struct Paramstruct{
    char* name;
    Typetable *type;
    int isPointer;
    struct Paramstruct *next;
} Paramstruct;

typedef struct Lsymbol{
    char* name;
    Typetable* type;
    int binding;
    int isPointer;
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

extern int breakStack[100];
extern int continueStack[100];
extern int loopTop;
extern int functionLabel;

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


Paramstruct* createParam(char *name, Typetable* type, int isPointer);

Lsymbol* LookupLocal(char *name);
void InstallLocal(char *name, Typetable* type);
void printLsymbol();

void setupFunction(char *name, Typetable *returnType, int returnIsPointer, Paramstruct *params);
int  codeGenTupleAddr(tnode *t);
void copyTuple(int dst, int src, int n);
tnode* buildCall(char *name, tnode *args);
int  paramMatchesArg(Paramstruct *p, tnode *a);
Gsymbol* LookupGlobal(char *name);
void resolveID(tnode *node);
void InstallLocalVar(char* name, Typetable *type, int isPointer);
void InstallParam(char* name, Typetable *type, int isPointer);
int computeLocalAddress(int offset);
int codeGenCall(tnode *t);
/* Error handling */
void yyerror(char* s);
void emitLoadLocal(int reg, int offset);
void emitStoreLocal(int reg, int offset);
#endif