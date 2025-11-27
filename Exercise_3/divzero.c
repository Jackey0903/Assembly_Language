/* DIVZERO.C - 演示除零异常 */
#include <dos.h>
#include <stdio.h>

int main() {
  int a = 100;
  int b = 0;
  int result;

  printf("Test: Divide by Zero\n");

  /* * 在 C 语言层面，直接写 a/b 编译器可能会优化报错。
   * 我们用内联汇编强制 CPU 执行除法指令
   */
  asm {
        mov ax, a
        mov bx, b
        div bl /* 执行除法 AX / BL (100 / 0) */
                          /* 这一步 CPU 硬件会检测到除数为0，自动触发 INT 0 */
  }

  /* 程序通常运行不到这里，会被中断终止 */
  printf("Result: %d\n", result);
  return 0;
}