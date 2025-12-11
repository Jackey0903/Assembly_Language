CODESEG SEGMENT ; 代码段
    ASSUME CS: CODESEG ; 设定代码段寄存器假设
    PUBLIC DISPLAY_NUMBER, DISPLAY_TAB, DISPLAY_NEWLINE ; 导出三个显示例程符号

DISPLAY_NUMBER PROC ; 显示寄存器DX:AX中的无符号十进制数，右侧补空格至宽度10
    PUSH CX ; 保存被调用者寄存器
    PUSH BX
    PUSH SI
    PUSH DI
    MOV DI, 10 ; 目标宽度=10位
    MOV SI, 0  ; 已生成的数字计数

NUMBER_CONVERSION_LOOP: ; 反复除以10，收集各位数字（余数）入栈，直到商与高位都为0
    MOV CX, 10 ; 除数=10
    CALL DIVIDE_DOUBLEWORD ; 用CX=10除DX:AX，返回新DX:AX为商，CX为余数
    PUSH CX ; 将余数（一位0..9）入栈
    INC SI ; 位数+1
    CMP AX, 0 ; 低16位商为0？
    JNZ NUMBER_CONVERSION_LOOP
    CMP DX, 0 ; 高16位商为0？
    JNZ NUMBER_CONVERSION_LOOP
    MOV BX, DI ; BX=总宽度
    SUB BX, SI ; BX=需要补的空格数

DISPLAY_DIGITS_LOOP: ; 从栈顶依次弹出并显示各位数字（高位到低位）
    POP DX ; DX低字节DL=数字0..9
    ADD DL, '0' ; 转为ASCII字符
    MOV AH, 02H ; DOS 显示字符功能
    INT 21H
    DEC SI ; 剩余位数-1
    JNZ DISPLAY_DIGITS_LOOP

DISPLAY_SPACES_LOOP: ; 显示右侧补齐的空格
    CMP BX, 0
    JLE DISPLAY_DONE
    MOV DL, ' '
    MOV AH, 02H
    INT 21H
    DEC BX
    JMP DISPLAY_SPACES_LOOP

DISPLAY_DONE:
    POP DI ; 恢复寄存器
    POP SI
    POP BX
    POP CX
    RET ; 返回，调用者负责设置DX:AX输入

DISPLAY_NUMBER ENDP

DIVIDE_DOUBLEWORD PROC ; 以CX为除数，计算DX:AX / CX，返回：DX:AX=商，CX=余数
    PUSH BX ; 暂存
    PUSH AX
    MOV AX, DX ; 先处理高16位：把DX移入AX
    MOV DX, 0 ; 清DX以进行16位除法
    DIV CX ; AX / CX，商->AX，余数->DX
    POP BX ; 取原AX低16位到BX（被除数低字）
    PUSH AX ; 保存高字除法得到的商（高位商）到栈
    MOV AX, BX ; 处理低16位：把原低字移入AX
    DIV CX ; 低字除以CX，并考虑上一步余数已在DX，实现跨位除法
    MOV CX, DX ; 低位除法的余数就是整体的余数，放入CX供调用者使用
    POP DX ; 从栈取回高位商到DX，AX当前为低位商，组合成32位商DX:AX
    POP BX ; 恢复
    RET

DIVIDE_DOUBLEWORD ENDP

DISPLAY_TAB PROC FAR ; 输出4个空格作为制表符
    PUSH DX
    PUSH AX
    MOV DL, ' '
    MOV AH, 02H
    INT 21H
    INT 21H
    INT 21H
    INT 21H
    POP AX
    POP DX
    RET

DISPLAY_TAB ENDP

DISPLAY_NEWLINE PROC FAR ; 输出回车换行（CR LF）
    PUSH DX
    PUSH AX
    MOV DL, 13 ; CR
    MOV AH, 02H
    INT 21H
    MOV DL, 10 ; LF
    MOV AH, 02H
    INT 21H
    POP AX
    POP DX
    RET

DISPLAY_NEWLINE ENDP

CODESEG ENDS ; 代码段结束

END ; 模块结束