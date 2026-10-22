#include <stdio.h>

void main() {
    int year;
    printf("请输入年份: ");
    scanf("%d", &year);

    if ((year % 4 == 0 && year % 100 != 0) || (year % 400 == 0)) {
        printf("%d 年是闰年", year);
    } else {
        printf("%d 年不是闰年", year);
    }
}