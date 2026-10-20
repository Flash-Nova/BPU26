/*
编程实现：任意输入一个三位整数，求这个数的百位数、十位数和个位数，并输出。提交代码与运行结果的截图
*/

#include <stdio.h>
int main() {
    int num; // num 固定是三位数
    printf("请输入一个三位十进制整数: ");
    scanf("%d", &num);

    printf("百位数 %d\n", num / 100); // 输出百位数
    printf("十位数 %d\n", (num / 10) % 10); // 输出十位数
    printf("个位数 %d", num % 10); // 输出个位数

    return 0;
}