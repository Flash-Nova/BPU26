#include <stdio.h>
void main() {

    int num, digit; // num 固定是二位数
    printf("输入一个两位十进制整数: ");
    scanf("%d", &num);

    printf("输入的数字是: %d\n", num);
    printf("十位数 %d\n", num / 10); // 输出十位数
    printf("个位数 %d", num % 10); // 输出个位数
}