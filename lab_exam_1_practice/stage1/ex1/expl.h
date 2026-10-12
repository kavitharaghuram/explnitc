#ifndef EXPL_H
#define EXPL_H

typedef struct tnode{
    int val;
    char* op;
    struct tnode* left;
    struct tnode* right;
} tnode;
tnode* makeLeafNode(int);
tnode* makeOperatorNode(char, tnode*, tnode*);
#endif 