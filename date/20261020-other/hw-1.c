/*
编写程序，实现输入摄氏温度c，输出华氏温度f，保留一位小数。提交代码与运行结果的截图
提示：f=c×9/5+32
*/

#include <stdio.h>
int main() {
    float c, f;
    printf("请输入摄氏温度: ");
    scanf("%f", &c);
    f = c * 9 / 5 + 32;
    printf("华氏温度为: %.1f\n", f);
    return 0;
}