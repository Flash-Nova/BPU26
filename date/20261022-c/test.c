// 测试链式赋值

#include <stdio.h>

void main() {
    int a, b, c;
    a = b = c = 5;
    printf("a = %d, b = %d, c = %d\n", a, b, c);
    printf("%d\n", a = 5);

    char ch;
    printf("%c\n", ch = 'A');
}