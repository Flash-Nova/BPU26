#include <stdio.h>
#define PI 3.14

int main() {

    // const double PI = 3.14;
    // 需指出，define 实际上不是个很好的代码习惯
    // 滥用 define 会污染主空间的命名环境
    // 实际上使用 const 或 C++11 引入的 constexpr 是更好的解决方案

    float radius = 0;
    printf("请输入圆的半径：");
    scanf("%f", &radius);
    printf("\n圆的面积是 %.2f", PI * radius * radius);

}