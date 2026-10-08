#include <stdio.h>
void main() {
    float a, b;
    a = 3.14;
    b = 0.618;
    
    printf("a 的值：%5.1f\n", a);
    printf("b 的值：%-5.1f\n\n", b);

    printf("a 的值：%f\n", a);
    printf("b 的值：%.2f\n", b);
}