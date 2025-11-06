#include <stdio.h>
#include <stdint.h>
#include <stdlib.h>

/*
This program demonstrates signed addition for 8-bit (byte) and 16-bit (word) operands in C,
and detects signed overflow by reading the CPU Overflow Flag (OF) via inline assembly.

Supported toolchains via conditional compilation:
- GCC/Clang on x86/x86_64: uses GNU inline asm with seto to read OF
- MSVC on x86: uses MS inline asm with seto to read OF

Note: Reading OF requires running on an x86-family CPU. If compiling on a non-x86 target,
these functions will fall back to a portable arithmetic overflow check as a last resort.
*/

static int add_int8_with_overflow(int8_t a, int8_t b, int8_t *result) {
    int overflow = 0;

    #if defined(__GNUC__) && (defined(__i386__) || defined(__x86_64__))
    int8_t sum = a;
    unsigned char of = 0;
    __asm__ volatile (
        "addb %2, %1;\n\t"
        "seto %0\n\t"
        : "=r"(of), "+q"(sum)
        : "q"(b)
        : "cc"
    );
    *result = sum;
    overflow = (int)of;
    #elif defined(_MSC_VER) && defined(_M_IX86)
    unsigned char of = 0;
    char sum;
    __asm {
        mov al, a
        add al, b
        seto dl
        mov sum, al
        mov of, dl
    }
    *result = (int8_t)sum;
    overflow = (int)of;
    #else
    /* Portable fallback (when x86 inline asm is unavailable): */
    int16_t wide = (int16_t)a + (int16_t)b;
    *result = (int8_t)wide;
    /* OF for signed add triggers when signs of a and b are same and differ from sum */
    overflow = (((a ^ *result) & (b ^ *result)) & 0x80) != 0;
    #endif

    return overflow;
}

static int add_int16_with_overflow(int16_t a, int16_t b, int16_t *result) {
    int overflow = 0;

    #if defined(__GNUC__) && (defined(__i386__) || defined(__x86_64__))
    int16_t sum = a;
    unsigned char of = 0;
    __asm__ volatile (
        "addw %2, %1;\n\t"
        "seto %0\n\t"
        : "=r"(of), "+r"(sum)
        : "r"(b)
        : "cc"
    );
    *result = sum;
    overflow = (int)of;
    #elif defined(_MSC_VER) && defined(_M_IX86)
    unsigned char of = 0;
    short sum;
    __asm {
        mov ax, a
        add ax, b
        seto dl
        mov sum, ax
        mov of, dl
    }
    *result = (int16_t)sum;
    overflow = (int)of;
    #else
    /* Portable fallback */
    int32_t wide = (int32_t)a + (int32_t)b;
    *result = (int16_t)wide;
    overflow = ((((a ^ *result) & (b ^ *result)) & 0x8000) != 0);
    #endif

    return overflow;
}

static void run_byte_mode(void) {
    int a_in, b_in;
    printf("[BYTE] 输入两个有符号8位整数 (-128..127): ");
    if (scanf("%d %d", &a_in, &b_in) != 2) {
        printf("输入无效\n");
        return;
    }
    if (a_in < -128 || a_in > 127 || b_in < -128 || b_in > 127) {
        printf("超出8位范围\n");
        return;
    }

    int8_t a = (int8_t)a_in;
    int8_t b = (int8_t)b_in;
    int8_t sum;
    int of = add_int8_with_overflow(a, b, &sum);

    if (of) {
        printf("溢出(OF=1): %d + %d 发生有符号溢出\n", a, b);
    } else {
        printf("结果: %d + %d = %d (OF=0)\n", a, b, sum);
    }
}

static void run_word_mode(void) {
    int a_in, b_in;
    printf("[WORD] 输入两个有符号16位整数 (-32768..32767): ");
    if (scanf("%d %d", &a_in, &b_in) != 2) {
        printf("输入无效\n");
        return;
    }
    if (a_in < -32768 || a_in > 32767 || b_in < -32768 || b_in > 32767) {
        printf("超出16位范围\n");
        return;
    }

    int16_t a = (int16_t)a_in;
    int16_t b = (int16_t)b_in;
    int16_t sum;
    int of = add_int16_with_overflow(a, b, &sum);

    if (of) {
        printf("溢出(OF=1): %d + %d 发生有符号溢出\n", a, b);
    } else {
        printf("结果: %d + %d = %d (OF=0)\n", a, b, sum);
    }
}

int main(void) {
    int mode = 0;
    printf("选择数据宽度: 1=BYTE(8位)  2=WORD(16位)\n");
    printf("请输入 1 或 2: ");
    if (scanf("%d", &mode) != 1) {
        printf("输入无效\n");
        return 1;
    }

    if (mode == 1) {
        run_byte_mode();
    } else if (mode == 2) {
        run_word_mode();
    } else {
        printf("无效的选择\n");
        return 1;
    }

    return 0;
}


