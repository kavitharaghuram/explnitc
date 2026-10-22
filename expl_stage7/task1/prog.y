%{
#include "expl.h"
int yylex();
int yyparse();

tnode* root;
FILE* target_file;
Typetable *currentType;
Typetable *currentTypeDef = NULL;
Fieldlist *currentFieldList = NULL, *currentFieldTail = NULL;
int fieldCount = 0;
Paramstruct *currentParamList = NULL;
Paramstruct *currentParamTail = NULL;
%}

%union{
    tnode* node;
    Typetable* ty;
}
%token BEGIN_ END READ WRITE
%token <node> NUM ID
%token IF ELSE THEN ENDIF
%token WHILE DO ENDWHILE
%token BREAK CONTINUE
%token LT GT LE GE EQ NE
%token REPEAT UNTIL
%token DECL ENDDECL INT STR
%token RETURN
%type <node> ReturnStmt
%type <node> ArgList
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
%type <node> FdefBlock
%type <node> Fdef
%type <node> Body
%type <node> CallStmt
%type <ty> TypeName
%token TYPE ENDTYPE NULL_ ALLOC FREE INITIALIZE
%type <node> Field
%token CLASS ENDCLASS EXTENDS NEW DELETE SELF
%type <node> MethodCall
%left LT GT LE GE EQ NE
%left '+' '-'
%left '*' '/'
%right USTAR '&'
%%

Program : TypeDefBlock ClassDefBlock GdeclBlock FdefBlock ;

ClassDefBlock
    : CLASS ClassDefList ENDCLASS
    |
    ;
ClassDefList : ClassDefList ClassDef | ClassDef ;

ClassDef
    : Cname '{' DECL ClassMembers ENDDECL MethodDefList '}'
      { checkMethodsDefined(Cptr); Cptr = NULL; }
    ;

Cname : ID { Cptr = CInstall($1->varname, NULL); } ;

ClassMembers : ClassMembers ClassMember | ;

ClassMember
    : TypeName ID ';'
      { Class_Finstall(Cptr, $1, lastClass, $2->varname); }
    | TypeName ID '(' ParamList ')' ';'
      {
          rejectClass($1, "method return type");
          Class_Minstall(Cptr, $2->varname, $1, 0, currentParamList);
          currentParamList = NULL; currentParamTail = NULL;
      }
    | TypeName '*' ID '(' ParamList ')' ';'
      {
          rejectClass($1, "method return type");
          Class_Minstall(Cptr, $3->varname, $1, 1, currentParamList);
          currentParamList = NULL; currentParamTail = NULL;
      }
    ;

MethodDefList : MethodDefList MethodDef | ;

MethodDef
    : TypeName ID '(' ParamList ')'
      { setupMethod($2->varname, $1, 0, currentParamList); }
      '{' Body '}'
      { finishMethod($8); currentParamList = NULL; currentParamTail = NULL; }
    | TypeName '*' ID '(' ParamList ')'
      { setupMethod($3->varname, $1, 1, currentParamList); }
      '{' Body '}'
      { finishMethod($9); currentParamList = NULL; currentParamTail = NULL; }
    ;

TypeDefBlock
    : TYPE TypeDefList ENDTYPE
    |
    ;
TypeDefList : TypeDefList TypeDef | TypeDef ;

TypeDef
    : ID { currentTypeDef = TInstall($1->varname, 0, NULL); }
      '{' FieldDeclList '}'
      {
          currentTypeDef->fields = currentFieldList;
          currentTypeDef->size = fieldCount;
          currentFieldList = NULL; currentFieldTail = NULL; fieldCount = 0;
      }
    ;
FieldDeclList : FieldDeclList FieldDecl | FieldDecl ;
FieldDecl
    : TypeName ID ';'
      {
        rejectClass($1, "field of a user-defined type");
        if(fieldCount >= 8){ printf("too many member fields\n"); exit(1); }
          for(Fieldlist *q = currentFieldList; q; q = q->next)
              if(!strcmp(q->name, $2->varname)){ printf("Duplicate field %s\n", $2->varname); exit(1); }
          Fieldlist *f = calloc(1, sizeof(Fieldlist));
          f->name = $2->varname; f->type = $1; f->fieldIndex = fieldCount++;
          if(!currentFieldList) currentFieldList = currentFieldTail = f;
          else { currentFieldTail->next = f; currentFieldTail = f; }
      }
    ;

LdeclBlock
    : DECL LdeclList ENDDECL
    | DECL ENDDECL
    ;

GdeclBlock
    : DECL GdeclList ENDDECL
    | DECL ENDDECL
    ;

LdeclList
    : LdeclList Ldecl
    | Ldecl
    ;

GdeclList
    : GdeclList Gdecl
    | Gdecl
    ;
    
TypeName
    : INT { $$ = tint; lastClass = NULL; }
    | STR { $$ = tstr; lastClass = NULL; }
    | ID  {
            $$ = TLookup($1->varname);
            if($$ != NULL) lastClass = NULL;
            else {
                Classtable *c = CLookup($1->varname);
                if(c == NULL){ printf("Undefined type %s\n", $1->varname); exit(1); }
                $$ = tclass; lastClass = c;
            }
          }
    ;
Gdecl
    :  TypeName { currentType = $1; currentCtype = lastClass; } GidList ';' ;

Ldecl
    : TypeName { rejectClass($1, "local variable"); currentType = $1; } LIdList ';' ;

LIdList
    : LIdList ',' ID { InstallLocalVar($3->varname, currentType, 0); }
    | ID              { InstallLocalVar($1->varname, currentType, 0); }
    ;
GidList
    : GidList ',' Gid
    | Gid
    ;

Gid
    : ID
      {
          Install($1->varname, currentType,
                  1, 0, 1, 1, 0,
                  NULL, 0);
      }

    | ID '[' NUM ']'
      {
          if($3->val <= 0){
              printf("Array size must be positive\n");
              exit(1);
          }

          Install($1->varname, currentType,
                  $3->val, 1, $3->val, 1, 0,
                  NULL, 0);
      }
    | ID '[' NUM ']' '[' NUM ']'
      {
          if($3->val <= 0 || $6->val <= 0){
              printf("Array size must be positive\n"); exit(1);
          }
          Install($1->varname, currentType,
                  $3->val * $6->val, 1, $3->val, $6->val, 0,
                  NULL, 0);
      }

    | ID '(' ParamList ')'
      {
          Install($1->varname, currentType,
                  0, 0, 1, 1, 0,
                  currentParamList, 1);

          currentParamList = NULL;
          currentParamTail = NULL;
      }
    | '*' ID '(' ParamList ')'
      {
          Install($2->varname, currentType, 0,0,1,1, 1, currentParamList, 1);  // isPointer=1
          currentParamList = NULL; currentParamTail = NULL;
      }
    ;

ParamList
    : ParamList ',' Param
    | Param
    |
    ;

Param
    : TypeName ID
      {
          rejectClass($1, "function parameter");
          Paramstruct *p = createParam($2->varname, $1, 0);
          if(currentParamList == NULL){ currentParamList = p; currentParamTail = p; }
          else{ currentParamTail->next = p; currentParamTail = p; }
      }
    | TypeName '*' ID
      {
          rejectClass($1, "function parameter");
          Paramstruct *p = createParam($3->varname, $1, 1);
          if(currentParamList == NULL){ currentParamList = p; currentParamTail = p; }
          else{ currentParamTail->next = p; currentParamTail = p; }
      }
    
    ;

FdefBlock
    : FdefBlock Fdef
    | Fdef
    ;

Fdef
    : TypeName ID '(' ParamList ')'
      {
          setupFunction($2->varname, $1, 0, currentParamList);
      }
      '{' Body '}'
      {
          currentFunction->body=$8;
          currentFunction->localCount=localVarCounter;
          printf("Function definition: %s\n", $2->varname);
          printLsymbol();
          $$ = $8;

          currentParamList = NULL;
          currentParamTail = NULL;
          currentFunction = NULL;
      }
    | TypeName '*' ID '(' ParamList ')'
      { 
        setupFunction($3->varname, $1, 1, currentParamList);
      }
      '{' Body '}'
      { currentFunction->body=$9; currentFunction->localCount=localVarCounter;
        $$=$9; currentParamList=NULL; currentParamTail=NULL; currentFunction=NULL; }
    
    ;
Body
    : LdeclBlock BEGIN_ Slist END
      {
          $$ = $3;
      }
    | BEGIN_ Slist END
      {
          $$ = $2;
      }
    ;
Slist
    : Slist Stmt { $$= createTree(0, tvoid, NULL, NODE_CONNECT, $1, NULL, $2);}
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
    | ReturnStmt { $$= $1; }
    | CallStmt {$$=$1;}
    ;
ReturnStmt
    : RETURN E ';'
      { checkReturn($2); $$ = createTree(0, tvoid, NULL, NODE_RETURN, $2, NULL, NULL); }
    ;
InputStmt
    : READ '(' ID ')' ';'
      {
          Lsymbol *lentry = LookupLocal($3->varname);

          if(lentry != NULL){
              $3->Lentry = lentry;
              $3->type = lentry->type;
              $3->isPointer = 0;
          }
          else{
              Gsymbol *entry = LookupVar($3->varname);

              if(entry == NULL){
                  printf("Variable %s not declared\n", $3->varname);
                  exit(1);
              }

              if(entry->isArray){
                  printf("cannot read array %s as a scalar\n", $3->varname);
                  exit(1);
              }

              $3->Gentry = entry;
              $3->type = entry->type;
              $3->isPointer = entry->isPointer;
          }

          $$ = createTree(0, tvoid, NULL, NODE_READ,
                          $3, NULL, NULL);
      }
    | READ '(' ID '[' E ']' ')' ';' {
            Gsymbol* entry=LookupVar($3->varname);
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
            $$=createTree(0, tvoid, NULL, NODE_READ, arr, NULL, NULL);
        }
    | READ '(' ID '[' E ']' '[' E ']' ')' ';' {
            Gsymbol* entry= LookupVar($3->varname);
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
            $$=createTree(0, tvoid, NULL, NODE_READ, arr, NULL, NULL);
        }
    | READ '(' Field ')' ';' {
          $$ = createTree(0, tvoid, NULL, NODE_READ, $3, NULL, NULL);
      }
    ;
OutputStmt
    : WRITE '(' E ')' ';' {$$= createTree(0, tvoid, NULL, NODE_WRITE, $3, NULL, NULL);}
    ;
AsgStmt
    : ID '=' E ';'
        {
            resolveID($1);
            if(!typesCompatible($1->type, $3->type)){
                printf("Type mismatch in assignment\n");
                exit(1);
            }
            $$ = createTree(0, tvoid, NULL, NODE_ASSIGN, $1, NULL, $3);
        }
    | ID '[' E ']' '[' E ']' '=' E ';' {
            Gsymbol* entry= LookupVar($1->varname);
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
            $$=createTree(0, tvoid, NULL, NODE_ASSIGN, arr, NULL, $9);
        }
    | ID '[' E ']' '=' E ';' {
        Gsymbol* entry= LookupVar($1->varname);
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
        $$= createTree(0, tvoid, NULL, NODE_ASSIGN, arr, NULL, $6);
    }
    | '*' ID '=' E ';' {
        Lsymbol *lentry = LookupLocal($2->varname);
        tnode *deref;
        if(lentry != NULL){
            if(!lentry->isPointer){ printf("%s is not a pointer\n", $2->varname); exit(1); }
            $2->Lentry = lentry; $2->type = lentry->type; $2->isPointer = 1;
        } else {
            Gsymbol *entry = LookupVar($2->varname);
            if(entry == NULL){ printf("Variable %s not declared", $2->varname); exit(1); }
            if(!entry->isPointer){ printf("%s is not a pointer\n", $2->varname); exit(1); }
            $2->Gentry = entry; $2->type = entry->type; $2->isPointer = 1;
        }
        deref = createTree(0, $2->type, NULL, NODE_DEREF, $2, NULL, NULL);
        deref->isPointer = 0;
        $$ = createTree(0, tvoid, NULL, NODE_ASSIGN, deref, NULL, $4);
    }
    | Field '=' E ';' {
          if(!typesCompatible($1->type, $3->type)){
              printf("Type mismatch in field assignment\n");
              exit(1);
          }
          $$ = createTree(0, tvoid, NULL, NODE_ASSIGN, $1, NULL, $3);
      }
    ;
IfStmt      
    : IF '(' E ')' THEN Slist ELSE Slist ENDIF ';'{
        $$= createTree(0, tvoid, NULL, NODE_IF, $3, $6, $8);
    }
    | IF '(' E ')' THEN Slist ENDIF ';' {
        $$= createTree(0, tvoid, NULL, NODE_IF, $3, $6, NULL);
    }
    ;
WhileStmt
    : WHILE '(' E ')' DO Slist ENDWHILE ';' {
        $$= createTree(0, tvoid, NULL, NODE_WHILE, $3, $6, NULL);
    }
    ;
BreakStmt
    : BREAK ';' {
        $$= createTree(0, tvoid, NULL, NODE_BREAK, NULL, NULL, NULL);
    }
    ;
ContinueStmt
    : CONTINUE ';' {
        $$= createTree(0, tvoid, NULL, NODE_CONTINUE, NULL, NULL, NULL);
    }
    ;
RepeatStmt
    : REPEAT Slist UNTIL '(' E ')' ';' {
        $$= createTree(0, tvoid, NULL, NODE_REPEAT, $2, NULL, $5);
    }
    ;
DoWhileStmt
    : DO Slist WHILE '(' E ')' ';' {
        $$= createTree(0, tvoid, NULL, NODE_DOWHILE, $2, NULL, $5);
    }
    ;
ArgList
    : ArgList ',' E
      {
          tnode *p = $1;

          while(p->next != NULL)
              p = p->next;

          p->next = $3;
          $$ = $1;
      }
    | E
      {
          $$ = $1;
      }
    |
      {
          $$ = NULL;
      }
    ;
E
    : E '+' E {$$= createTree(0, tint,  NULL, NODE_PLUS, $1, NULL, $3); }
    | E '-' E {$$= createTree(0, tint,  NULL, NODE_MINUS, $1, NULL, $3); }
    | E '*' E {$$= createTree(0, tint,  NULL, NODE_MUL, $1, NULL, $3); }
    | E '/' E {$$= createTree(0, tint,  NULL, NODE_DIV, $1, NULL, $3); }
    | E LT E { $$ = createTree(0, tbool, NULL, NODE_LT, $1, NULL, $3); }
    | E GT E { $$ = createTree(0, tbool, NULL, NODE_GT, $1, NULL, $3); }
    | E LE E { $$ = createTree(0, tbool, NULL, NODE_LE, $1, NULL, $3); }
    | E GE E { $$ = createTree(0, tbool, NULL, NODE_GE, $1, NULL, $3); }
    | E EQ E { $$ = createTree(0, tbool, NULL, NODE_EQ, $1, NULL, $3); }
    | E NE E { $$ = createTree(0, tbool, NULL, NODE_NE, $1, NULL, $3); }
    | '(' E ')' {$$= $2; }
    | NUM {$$= $1; }
    | ID '[' E ']' {
            Gsymbol* entry = LookupVar($1->varname);
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
            $1->isPointer=entry->isPointer;
            $$= createTree(0, entry->type, NULL, NODE_ARRAY, $1, NULL, $3);
        }
    | ID '[' E ']' '[' E ']' {
            Gsymbol* entry = LookupVar($1->varname);
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
            $1->isPointer=entry->isPointer;
            tnode* row=createTree(0, entry->type, NULL, NODE_ARRAY, $1, NULL, $3);
            $$=createTree(0, entry->type, NULL, NODE_ARRAY, row, NULL, $6);
        }
    | ID
      {
          resolveID($1);
          $$ = $1;
      }
    | '&' ID {
        resolveID($2);
        
        if($2->Gentry && $2->Gentry->isArray){
            printf("Cannot take address of array %s\n", $2->varname); exit(1);
        }
        $$ = createTree(0, $2->type, NULL, NODE_ADDR, $2, NULL, NULL);
        $$->isPointer = 1;
        
    }
    | '*' ID %prec USTAR {
        Lsymbol *lentry = LookupLocal($2->varname);
        if(lentry != NULL){
            if(!lentry->isPointer){
                printf("%s is not a pointer\n", $2->varname);
                exit(1);
            }
            $2->Lentry = lentry;
            $2->type = lentry->type;
            $2->isPointer = 1;
            $$ = createTree(0, lentry->type, NULL, NODE_DEREF, $2, NULL, NULL);
            $$->isPointer = 0;
        }
        else{
            Gsymbol *entry = LookupVar($2->varname);
            if(entry == NULL){ printf("Variable %s is not declared\n", $2->varname); exit(1); }
            if(!entry->isPointer){ printf("%s is not a pointer\n", $2->varname); exit(1); }
            $2->Gentry = entry;
            $2->type = entry->type;
            $2->isPointer = 1;
            $$ = createTree(0, entry->type, NULL, NODE_DEREF, $2, NULL, NULL);
            $$->isPointer = 0;
        }
    }

    | ID '(' ArgList ')'
      {
          $$ = buildCall($1->varname, $3);
      }
    | Field { $$ = $1; }
        | NULL_       { $$ = createTree(0, tnull, NULL, NODE_NULL, NULL, NULL, NULL); }
    | ALLOC '(' ')'      { $$ = createTree(0, tnull, NULL, NODE_ALLOC, NULL, NULL, NULL); }
    | INITIALIZE '(' ')' { $$ = createTree(0, tint,  NULL, NODE_INIT,  NULL, NULL, NULL); }
    | FREE '(' E ')'     {
          if(!isUserType($3->type)){ printf("free() needs a user-defined type\n"); exit(1); }
          $$ = createTree(0, tint, NULL, NODE_FREE, $3, NULL, NULL);
      }
    | MethodCall { $$ = $1; }
    | NEW '(' ID ')' {
          Classtable *c = CLookup($3->varname);
          if(!c){ printf("new: %s is not a class\n", $3->varname); exit(1); }
          $$ = createTree(0, tclass, NULL, NODE_NEW, NULL, NULL, NULL);
          $$->ctype = c;
      }
    ;
Field
    : ID '.' ID    { resolveID($1); $$ = buildFieldAccess($1, $3->varname); }
    | Field '.' ID { $$ = buildFieldAccess($1, $3->varname); }
    | ID '[' E ']' '.' ID
      {
          Gsymbol *entry = LookupVar($1->varname);
          if(entry == NULL){ printf("Variable %s not declared\n", $1->varname); exit(1); }
          if(!entry->isArray){ printf("%s is not an array\n", $1->varname); exit(1); }
          if($3->nodetype == NODE_NUM && ($3->val < 0 || $3->val >= entry->size)){
              printf("array index out of bounds\n"); exit(1);
          }
          $1->Gentry = entry;
          $1->type = entry->type;
          tnode *arr = createTree(0, entry->type, NULL, NODE_ARRAY, $1, NULL, $3);
          $$ = buildFieldAccess(arr, $6->varname);
      }
    | ID '[' E ']' '[' E ']' '.' ID
      {
          Gsymbol *entry = LookupVar($1->varname);
          if(entry == NULL){ printf("Variable %s not declared\n", $1->varname); exit(1); }
          if(!entry->isArray || entry->cols == 1){
              printf("%s is not a 2d array\n", $1->varname); exit(1);
          }
          if($3->nodetype == NODE_NUM && ($3->val < 0 || $3->val >= entry->rows)){
              printf("row index out of bounds\n"); exit(1);
          }
          if($6->nodetype == NODE_NUM && ($6->val < 0 || $6->val >= entry->cols)){
              printf("column index out of bounds\n"); exit(1);
          }
          $1->Gentry = entry;
          $1->type = entry->type;
          tnode *row = createTree(0, entry->type, NULL, NODE_ARRAY, $1, NULL, $3);
          tnode *arr = createTree(0, entry->type, NULL, NODE_ARRAY, row, NULL, $6);
          $$ = buildFieldAccess(arr, $9->varname);
      }
    | SELF '.' ID { $$ = buildSelfField($3->varname); }
    ;
CallStmt
    : ID '(' ArgList ')' ';'
      { $$ = buildCall($1->varname, $3); }
    | INITIALIZE '(' ')' ';'
      { $$ = createTree(0, tvoid, NULL, NODE_INIT, NULL, NULL, NULL); }
    | FREE '(' E ')' ';'
      {
          if(!isUserType($3->type)){ printf("free() needs a user-defined type\n"); exit(1); }
          $$ = createTree(0, tvoid, NULL, NODE_FREE, $3, NULL, NULL);
      }
    | MethodCall ';' { $$ = $1; }
    | DELETE '(' E ')' ';' {
          if($3->type != tclass){ printf("delete needs a class variable\n"); exit(1); }
          $$ = createTree(0, tvoid, NULL, NODE_DELETE, $3, NULL, NULL);
      }
    ;
MethodCall
    : ID '.' ID '(' ArgList ')'    { resolveID($1); $$ = buildMethodCall($1, $3->varname, $5); }
    | SELF '.' ID '(' ArgList ')'  { $$ = buildMethodCall(makeSelf(), $3->varname, $5); }
    | Field '.' ID '(' ArgList ')' { $$ = buildMethodCall($1, $3->varname, $5); }
    ;

%%

int main(){
    target_file = fopen("output.xsm", "w");
    TypeTableCreate();
    yyparse();
    printClassTable();  
    Gsymbol *m = LookupVar("main");
    if(!m || !m->isFunction || !m->body){ printf("main not defined\n"); exit(1); }


    writeHeader();  
    for(Gsymbol *g = Ghead; g; g = g->next)
        if(!g->isFunction && isUserType(g->type))
            for(int k = 0; k < g->size; k++){
                fprintf(target_file, "MOV R0, 0\n");
                fprintf(target_file, "MOV [%d], R0\n", g->binding + k);
            }
    fprintf(target_file, "PUSH R0\n");  // return slot for main
    fprintf(target_file, "CALL F%d\n", m->flabel);
    writeExit();

    for(Gsymbol *g = Ghead; g; g = g->next){
        if(!g->isFunction || !g->body) continue;
        currentFunction = g;
        fprintf(target_file, "F%d:\n", g->flabel);
        fprintf(target_file, "PUSH BP\nMOV BP, SP\n");
        if(g->localCount) fprintf(target_file, "ADD SP, %d\n", g->localCount);
        for(int i = 1; i <= g->localCount; i++){
            fprintf(target_file, "MOV R0, BP\nADD R0, %d\nMOV R1, 0\nMOV [R0], R1\n", i);
        }
        codeGen(g->body);
    }
    
    writeArrayErrorHandler();
    fclose(target_file);
    return 0;
}