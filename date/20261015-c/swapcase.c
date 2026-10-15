#include <stdio.h>

void main() {
    char temp;
    scanf("%c", &temp);
    if (temp >= 'A' && temp <= 'Z') {
        printf("%c", temp + ' ');
    } else if (temp >= 'a' && temp <= 'z') {
        printf("%c", temp - ' ');
    } else {
        printf("%c", temp);
    }
}