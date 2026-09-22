%{
#include "expl.h"
int yylex();
int yyparse();

int currentType;
tnode* root;
FILE* target_file;
Paramstruct *currentParamList = NULL;
Paramstruct *currentParamTail = NULL;
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
%right USTAR '&'
%%

Program
    : GdeclBlock BEGIN_ Slist END ';'
      {
          root = $3;
      }
    | GdeclBlock BEGIN_ END ';'
      {
          root = NULL;
      }
    ;
Type
    : INT { $$= TYPE_INT; }
    | STR { $$= TYPE_STR; }
    ;

GdeclBlock
    : DECL GdeclList ENDDECL
    | DECL ENDDECL
    ;

GdeclList
    : GdeclList Gdecl
    | Gdecl
    ;

Gdecl
    : Type { currentType = $1; } GidList ';'
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

    | ID '(' ParamList ')'
      {
          Install($1->varname, currentType,
                  0, 0, 1, 1, 0,
                  currentParamList, 1);

          currentParamList = NULL;
          currentParamTail = NULL;
      }
    ;

ParamList
    : ParamList ',' Param
    | Param
    |
    ;

Param
    : Type ID
      {
          Paramstruct *p = createParam($2->varname, $1);

          if(currentParamList == NULL){
              currentParamList = p;
              currentParamTail = p;
          }
          else{
              currentParamTail->next = p;
              currentParamTail = p;
          }
      }
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
        $1->isPointer=entry->isPointer;
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
    | '*' ID '=' E ';' {
            Gsymbol* entry= Lookup($2->varname);
            if(entry==NULL){
                printf("Variable %s not declared", $2->varname);
                exit(1);
            }
            if(!entry->isPointer){
                printf("%s is not a pointer\n", $2->varname);
                exit(1);
            }
            $2->Gentry=entry;
            $2->type=entry->type;
            $2->isPointer=1;
            tnode* deref= createTree(0, entry->type, NULL, NODE_DEREF, $2, NULL, NULL);
            deref->isPointer=0;
            $$=createTree(0, TYPE_NONE, NULL, NODE_ASSIGN, deref, NULL, $4);
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
            $1->isPointer=entry->isPointer;
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
            $1->isPointer=entry->isPointer;
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
            $1->isPointer=entry->isPointer;
        }
    | '&' ID {
            Gsymbol* entry= Lookup($2->varname);
            if(entry==NULL){
                printf("Variable %s not declared\n", $2->varname);
                exit(1);
            }
            if(entry->isArray){
                printf("Cannot take address of array %s\n", $2->varname);
                exit(1);
            }
            $2->Gentry=entry;
            $2->type=entry->type;
            $2->isPointer=entry->isPointer;
            $$= createTree(0, entry->type, NULL, NODE_ADDR, $2, NULL, NULL);
            $$->isPointer=1;
        }
    | '*' ID %prec USTAR {
            Gsymbol* entry= Lookup($2->varname);
            if(entry==NULL){
                printf("variable %s is not declared\n", $2->varname);
                exit(1);
            }
            if(!entry->isPointer){
                printf("%s is not a pointer\n", $2->varname);
                exit(1);
            }
            $2->Gentry=entry;
            $2->type=entry->type;
            $2->isPointer=1;
            $$=createTree(0, entry->type, NULL, NODE_DEREF, $2, NULL, NULL);
       
            $$->isPointer=0;
    }
    
    ;


%%


int main()
{
    yyparse();

    printGsymbol();
    return 0;
}