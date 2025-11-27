/*
 * 作业：BIOS中断调用 (int 16h & int 10h)
 * 目标：获取键盘输入并显示，按 Shift 退出
 * 限制：严禁使用 int 21h (即不能用 printf/scanf 等)
 */

void bios_putc(char c);
void bios_puts(char *str);
int get_shift_status();
int check_key_buffer();
char get_key();

int main() {
  char c;

  /* 1. 打印提示信息 (模拟 printf) */
  bios_puts("BIOS Interrupt Homework\r\n");
  bios_puts("-----------------------\r\n");
  bios_puts("Type anything. Press [Shift] to Quit.\r\n\r\n");

  /* 2. 主循环 */
  while (1) {
    /* --- 步骤 A: 检查 Shift 键是否按下 --- */
    /* 如果检测到 Left Shift (Bit 1) 或 Right Shift (Bit 0) */
    if (get_shift_status() & 0x03) {
      bios_puts("\r\n[Shift] detected. Exiting...\r\n");
      break; /* 退出循环 */
    }

    /* --- 步骤 B: 检查是否有普通按键在等待 --- */
    if (check_key_buffer()) {
      /* 如果有按键，读取它 */
      c = get_key();

      /* 回显字符到屏幕 */
      /* 特殊处理回车键 (Enter): int 16h 读到的是 \r (0x0D) */
      /* 但屏幕显示通常需要 \r\n 才能换行 */
      if (c == 0x0D) {
        bios_putc(0x0D); /* CR 回车 */
        bios_putc(0x0A); /* LF 换行 */
      } else {
        bios_putc(c);
      }
    }
  }

  return 0;
}

/* ===========================================================
   底层函数实现 (Inline Assembly)
   =========================================================== */

/* * 功能：调用 int 10h (AH=0Eh) 在屏幕打印一个字符
 * 这是 BIOS 提供的"电传打字机输出"模式
 */
void bios_putc(char c) {
  asm {
        mov ah, 0x0E /* 功能号：在光标处写字符 */
        mov al, c /* 要写的字符 */
        mov bl, 0x07 /* 颜色属性 (黑底白字) */
        int 0x10 /* 调用 BIOS 视频中断 */
  }
}

/* * 功能：循环调用 bios_putc 打印字符串
 * 替代 C 语言的 printf/puts
 */
void bios_puts(char *str) {
  while (*str) {
    bios_putc(*str++);
  }
}

/* * 功能：调用 int 16h (AH=02h) 获取键盘修饰键状态
 * 返回值：AL 寄存器的内容 (状态字节)
 * Bit 0: Right Shift按下为1
 * Bit 1: Left Shift按下为1
 */
int get_shift_status() {
  unsigned char status;
  asm {
        mov ah, 0x02 /* 功能号：读取键盘状态 */
        int 0x16 /* 调用 BIOS 键盘中断 */
        mov status, al /* 结果在 AL 中 */
  }
  return status;
}

/* * 功能：调用 int 16h (AH=01h) 检查缓冲区是否有字符
 * 返回值：1 (有字符), 0 (无字符)
 * 原理：如果 ZF (零标志位) = 0，表示有字符；ZF = 1，表示无字符
 */
int check_key_buffer() {
  int has_key = 0;
  asm {
        mov ah, 0x01 /* 功能号：查询键盘缓冲区 */
        int 0x16
        jz no_key /* Jump if Zero: 如果 ZF=1，跳转到无按键处理 */
        mov has_key, 1 /* 否则标记为有按键 */
  }
  no_key : return has_key;
}

/* * 功能：调用 int 16h (AH=00h) 读取一个字符
 * 注意：这是阻塞调用，但我们只在 check_key_buffer 确认有货后才调它
 */
char get_key() {
  char key;
  asm {
        mov ah, 0x00 /* 功能号：从缓冲区读字符 */
        int 0x16
        mov key, al /* ASCII 码在 AL 中 */
  }
  return key;
}