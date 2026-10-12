#ifndef EXPL_H
#define EXPL_H
#define TYPE_INT 1
#define TYPE_BOOL 2
#define TYPE_NONE 3

#define NODE_NUM 1
#define NODE_ID 2
#define NODE_PLUS 3
#define NODE_MINUS 4
#define NODE_MUL 5
#define NODE_DIV 6
#define NODE_ASSIGN 7
#define NODE_CONNECT 8
#define NODE_READ 9
#define NODE_WRITE 10
#define NODE_IF 11
#define NODE_WHILE 12
#define NODE_LT 13
#define NODE_LE 14
#define NODE_GT 15
#define NODE_GE 16
#define NODE_EQ 17
#define NODE_NE 18
typedef struct tnode {
    int val;
    char* varname;
    int type;
    int nodetype;
    struct tnode* left;
    struct tnode* right;
    struct tnode* middle;
} tnode;
tnode* createTree(int val, int type, char* varname, int nodetype, tnode* left, tnode* middle, tnode* right);


#endif