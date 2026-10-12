#ifndef EXPL_H
#define EXPL_H
#define TYPE_INT 1

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
typedef struct tnode{
    char *varname;
    int val;
    int type;
    int node_type;
    struct tnode* left;
    struct tnode* right;
} tnode;
tnode* createTree(int val, int type, char* varname, int node_type, tnode* left, tnode* right);
void printTree(tnode* root);
#endif