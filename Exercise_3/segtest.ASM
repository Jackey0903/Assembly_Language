; ============================================
; 作业：段间跳转演示 (远跳转/远调用)
; 编译方法: MASM SEGTEST.ASM; -> LINK SEGTEST.OBJ;
; ============================================

DATA SEGMENT
    MSG1 DB 'In CODE_A Segment (Main).', 0Dh, 0Ah, '$'
    MSG2 DB 'Jumped to CODE_B Segment!', 0Dh, 0Ah, '$'
    MSG3 DB 'Back in CODE_A Segment.', 0Dh, 0Ah, '$'
DATA ENDS

; --------------------------------------------
; 定义堆栈段 (必须有，否则远跳转可能出错)
; --------------------------------------------
STACK_SEG SEGMENT STACK
    DW 100 DUP(?)
STACK_SEG ENDS

; --------------------------------------------
; 代码段 B (被调用的段)
; --------------------------------------------
CODE_B SEGMENT
    ASSUME CS:CODE_B

    ; 定义一个 FAR 过程 (供外部调用)
    FUNC_IN_SEG_B PROC FAR
        ; 打印 MSG2
        MOV AX, DATA
        MOV DS, AX
        LEA DX, MSG2
        MOV AH, 09H
        INT 21H
        
        RETF  ; <--- 关键：必须用 RETF (Far Return) 返回，它会同时弹出 IP 和 CS
    FUNC_IN_SEG_B ENDP

CODE_B ENDS

; --------------------------------------------
; 代码段 A (主程序段)
; --------------------------------------------
CODE_A SEGMENT
    ASSUME CS:CODE_A, DS:DATA, SS:STACK_SEG
START:
    ; 初始化 DS
    MOV AX, DATA
    MOV DS, AX

    ; 1. 打印第一句话
    LEA DX, MSG1
    MOV AH, 09H
    INT 21H

    ; 2. 段间调用 (Far Call)
    ; 这里的调用会改变 CS 和 IP
    ; 观察 DEBUG 时：CS 会变成 CODE_B 的段地址
    CALL FAR PTR FUNC_IN_SEG_B 

    ; 3. 返回后打印第三句话
    LEA DX, MSG3
    MOV AH, 09H
    INT 21H

    ; 退出程序
    MOV AH, 4CH
    INT 21H

CODE_A ENDS

END START