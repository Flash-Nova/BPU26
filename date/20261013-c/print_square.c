#include <stdio.h>
void main() {
    int num;
    printf("请输入一个数：");
    scanf("%d", &num);
    printf("\n%d 的平方为 %d \n", num, num * num);
}