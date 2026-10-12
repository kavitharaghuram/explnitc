#ifndef EXPL_H
#define EXPL_H
typedef struct tnode{
    char* op;
    int val;
    struct tnode* left;
    struct tnode* right;
} tnode;

tnode* makeLeafNode(int n);
tnode* makeOperatorNode(char, tnode*, tnode*);
#endif
