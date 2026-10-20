#include <stdio.h>
void main() {
    
    float x = 5.4;
    int b = (int)x;
    printf("b = %d\n", b);

    // printf("b = %d", int(x));
    // C 语言需避免形如 int(x) 这种写法
    // 这是 C++98 才引入的功能

    x = 5.6;
    b = (int)x;
    printf("b = %d", b);

    // 如果需要四舍五入，浮点数可以通过 %.xf 来实现
    // 或者使用 round() 函数
    // 也可以通过加 0.5 再取整的方式实现四舍五入
}