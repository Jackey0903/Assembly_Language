STKSEG SEGMENT ; 堆栈段，分配32个字（64字节）作为程序堆栈
    DW 32 DUP(0)
STKSEG ENDS

DATASEG SEGMENT ; 数据段，包含年份、收入、员工数三张原始数据表
    YEARS DB '1975','1976','1977','1978','1979','1980','1981','1982','1983','1984','1985','1986','1987','1988','1989','1990','1991','1992','1993','1994','1995' ; 21年，每年4字节ASCII
    INCOMES DD 16,22,382,1356,2390,8000,16000,24486,50065,97479,140417,197514,345980,590827,803530,1183000,1843000,2759000,3753000,4649000,5937000 ; 21个双字收入（32位）
    EMPLOYEES DW 3,7,9,13,28,38,130,220,476,778,1001,1442,2258,2793,4037,5635,8226,11542,14430,15257,17800 ; 21个字员工数（16位）
DATASEG ENDS

TABLE SEGMENT ; 目标表段：每行16字节布局，初始填充占位字符串
    DB 21 DUP('year summ ne ??') ; 每行：year(4) + 空格(1) + income(4) + 空格(1) + employees(2) + 空格(1) + average(2) + '\0'(1) ≈ 16字节
TABLE ENDS

CODESEG SEGMENT
    ASSUME CS: CODESEG, DS: DATASEG, ES:TABLE ; 代码段寄存器假设
    EXTRN DISPLAY_NUMBER: FAR, DISPLAY_TAB: FAR, DISPLAY_NEWLINE: FAR ; 声明外部显示子程序

MAIN_PROC PROC FAR ; 入口过程（远过程）
    MOV AX, DATASEG ; 加载数据段选择子
    MOV DS, AX
    MOV AX, TABLE ; 加载表段选择子
    MOV ES, AX
    MOV CX, 21 ; 循环次数=21年
    MOV SI, OFFSET YEARS ; SI指向年份源
    MOV DI, 0 ; DI指向表目的起始

COPY_YEARS_LOOP: ; 拷贝每年4字节ASCII到表行开头
    MOVSB ; 复制1字节：Y1
    MOVSB ; 复制1字节：Y2
    MOVSB ; 复制1字节：Y3
    MOVSB ; 复制1字节：Y4
    ADD DI, 12 ; 跳到下一行的年份列（每行16字节，已写4字节，再前进12）
    LOOP COPY_YEARS_LOOP
    MOV CX, 21
    MOV SI, OFFSET INCOMES ; 收入源（双字）
    MOV DI, 5 ; 表中收入列偏移（year后1空格）

COPY_INCOMES_LOOP: ; 将32位收入按低/高字写入表
    MOV AX, [SI] ; 低16位
    MOV DX, [SI + 2] ; 高16位
    MOV ES:[DI], AX
    MOV ES:[DI + 2], DX ; 存4字节收入
    ADD DI, 16 ; 到下一行收入列
    ADD SI, 4 ; 下个收入
    LOOP COPY_INCOMES_LOOP
    MOV CX, 21
    MOV SI, OFFSET EMPLOYEES ; 员工源（字）
    MOV DI, 10 ; 表中员工列偏移（income后1空格）

COPY_EMPLOYEES_LOOP: ; 写入员工数（16位）
    MOV AX, [SI]
    MOV ES:[DI], AX
    ADD DI, 16 ; 下一行
    ADD SI, 2 ; 下个员工数
    LOOP COPY_EMPLOYEES_LOOP
    MOV CX, 21
    MOV BX, 13 ; 平均收入列偏移（employees后1空格）
    MOV SI, OFFSET INCOMES ; 为计算平均数再遍历收入
    MOV DI, OFFSET EMPLOYEES ; DI遍历员工

CALCULATE_AVERAGES_LOOP: ; 计算平均收入=INCOME / EMPLOYEES，结果写入表
    PUSH BX ; 保存平均列偏移
    MOV AX, [SI] ; INCOME低16
    MOV DX, [SI + 2] ; INCOME高16 -> 构成32位被除数DX:AX
    ADD SI, 4
    MOV BX, [DI] ; 取员工数作除数
    ADD DI, 2
    DIV BX ; 32位 / 16位：商在AX，余数在DX
    POP BX ; 取回平均列偏移
    PUSH DI ; 暂存当前员工迭代指针
    MOV DI, BX ; 用DI定位到平均列
    MOV ES:[DI], AX ; 写入平均（只存16位商）
    ADD DI, 16 ; 跳至下一行平均列
    MOV BX, DI ; 更新BX为下一行平均列偏移
    POP DI ; 恢复员工指针
    LOOP CALCULATE_AVERAGES_LOOP
    MOV BX, 21 ; 打印循环次数
    MOV SI, 0 ; 从表段起始遍历打印
    MOV AX, TABLE
    MOV DS, AX ; 切换DS指向TABLE以便打印

PRINT_TABLE_LOOP: ; 打印一行：年、收入、员工、平均
    CALL DISPLAY_TAB ; 左边缩进
    MOV CX, 4 ; 年份4字符

PRINT_YEAR:
    MOV DL, [SI] ; 输出一个字符
    MOV AH, 02H
    INT 21H
    INC SI
    LOOP PRINT_YEAR
    CALL DISPLAY_TAB
    CALL DISPLAY_TAB
    CALL DISPLAY_TAB ; 三个TAB使列对齐
    INC SI ; 跳过 year 后的空格
    MOV AX, [SI] ; 取收入低16
    ADD SI, 2
    MOV DX, [SI] ; 取收入高16
    ADD SI, 2
    CALL DISPLAY_NUMBER ; 显示32位十进制数（使用UTILS里的转换）
    CALL DISPLAY_TAB
    CALL DISPLAY_TAB ; 两个TAB
    INC SI ; 跳过 income 后的空格
    MOV AX, [SI] ; 员工数（16位）
    MOV DX, 0
    ADD SI, 2
    CALL DISPLAY_NUMBER
    CALL DISPLAY_TAB
    CALL DISPLAY_TAB
    INC SI ; 跳过 employees 后的空格
    MOV AX, [SI] ; 平均（16位）
    MOV DX, 0
    ADD SI, 2
    CALL DISPLAY_NUMBER
    INC SI ; 跳过行末占位或终止符
    CALL DISPLAY_NEWLINE ; 换行
    DEC BX
    JNZ PRINT_TABLE_LOOP ; 直到21行打印完
    MOV AX, 4C00H ; 程序结束
    INT 21H

MAIN_PROC ENDP

CODESEG ENDS

END MAIN_PROC ; 指定程序入口符号