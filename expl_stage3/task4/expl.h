#ifndef EXPL_H
#define EXPL_H

#include<stdio.h>
#include<stdlib.h>
#include<string.h>

#define TYPE_NONE -1
#define TYPE_BOOL 0
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
typedef struct tnode{
    int val; //value of number for NUM nodes
    int nodetype; //info about non-leaf nodes
    int type; //type of variable
    char *varname; //name of variables for id 
    struct tnode *left;
    struct tnode* middle;
    struct tnode *right;
} tnode;

tnode* createTree(int val, int type, char* varname, int nodetype, tnode* left, tnode* middle, tnode* right);

#endif