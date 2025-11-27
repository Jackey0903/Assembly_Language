/* * 实验名称：重写溢出中断服务程序 (INT 4)
 * 文件名：OVERFLOW.C
 * 编译环境：Turbo C 2.0 (DOSBox)
 */

#include <conio.h>
#include <dos.h>
#include <stdio.h>

/* 定义函数指针，用于保存系统原有的中断向量 */
void interrupt (*old_handler)(void);

/* * 自定义中断服务程序 (ISR)
 * 当 INTO 指令检测到 OF=1 时，CPU 会跳转到这里执行
 */
void interrupt new_overflow_handler(void) {
  /* 打印与截图一致的星号框警告 */
  printf("\n\n****************************************\n");
  printf("* [SYSTEM ALERT] Overflow Detected!    *\n");
  printf("* Exception handled by Custom INT 4    *\n");
  printf("****************************************\n\n");
}

int main() {
  int a = 32767;
  int b = 1;

  /* 清屏，确保截图背景干净 */
  clrscr();

  /* 打印头部标题 */
  printf("Experiment: Rewriting Overflow Interrupt Handler\n");
  printf("------------------------------------------------\n");

  /* 1. 保存旧中断 */
  old_handler = getvect(4);
  printf("[Step 1] Original INT 4 vector saved.\n");

  /* 2. 安装新中断 */
  setvect(4, new_overflow_handler);
  printf("[Step 2] New INT 4 handler installed.\n");

  /* 3. 准备计算 */
  printf("[Step 3] Performing calculation: %d + %d ...\n", a, b);

  /* 4. 内联汇编核心部分 */
  asm {
        mov ax, a /* AX = 32767 */
        add ax, b /* AX = -32768 (溢出，OF置1) */
        into /* 检测 OF=1 -> 触发 INT 4 -> 调用 new_overflow_handler */
  }

  /* 5. 中断返回后继续执行 */
  printf("[Step 4] Calculation logic returned to main.\n");

  /* 6. 恢复现场 */
  setvect(4, old_handler);
  printf("[Step 5] Original INT 4 vector restored.\n");

  getch();

  return 0;
}