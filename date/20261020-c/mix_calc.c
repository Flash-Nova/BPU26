#include <stdio.h>
void main() {
    int a = 5, b = 3, c = 25, d = 12;
    float div;
    int mo, add, abstract;
    /* 使用算术运算符 */
    div = a / b; // 除法
    mo = a % b; // 求模
    add = ++c;
    abstract = --d;
    printf("商为 %f\n", div);
    printf("余数为 %d\n", mo);
    printf("加 1 后为 %d\n", add);
    printf("减 1 后为 %d\n", abstract);
}