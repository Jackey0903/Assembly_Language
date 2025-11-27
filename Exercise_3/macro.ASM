; ============================================
; 作业：MACRO vs PROC 及 字符串指令
; ============================================

; 1. 定义宏 (MACRO)
; 宏在汇编阶段会被"展开"，即把代码直接复制到调用处
SHOW_STR_MACRO MACRO STRING_ADDR
    PUSH AX
    PUSH DX
    LEA DX, STRING_ADDR
    MOV AH, 09H
    INT 21H
    POP DX
    POP AX
ENDM

DATA SEGMENT
    STR_M DB 'Output via MACRO', 0Dh, 0Ah, '$'
    STR_P DB 'Output via PROCEDURE', 0Dh, 0Ah, '$'
    COPY_SRC DB 'SourceString'
    COPY_DST DB 12 DUP(?)  ; 预留空间
DATA ENDS

CODE SEGMENT
    ASSUME CS:CODE, DS:DATA, ES:DATA
START:
    MOV AX, DATA
    MOV DS, AX
    MOV ES, AX  ; 字符串指令通常需要 ES 配合

    ; ---------------------------
    ; A. 测试 MACRO (宏)
    ; ---------------------------
    ; 汇编器会在这里直接插入 SHOW_STR_MACRO 的所有代码
    SHOW_STR_MACRO STR_M  

    ; ---------------------------
    ; B. 测试 PROCEDURE (过程)
    ; ---------------------------
    ; CPU 会跳转(CALL)到下面的 SHOW_STR_PROC 地址去执行
    LEA DX, STR_P
    CALL SHOW_STR_PROC

    ; ---------------------------
    ; C. 字符串处理指令 (MOVSB)
    ; ---------------------------
    ; 将 COPY_SRC 复制到 COPY_DST
    LEA SI, COPY_SRC   ; 源地址 DS:SI
    LEA DI, COPY_DST   ; 目的地址 ES:DI
    MOV CX, 12         ; 复制长度
    CLD                ; 清除方向标志，正向复制
    REP MOVSB          ; 重复移动字节 (Repeat Move String Byte)

    ; 退出
    MOV AH, 4CH
    INT 21H

    ; ---------------------------
    ; 过程定义
    ; ---------------------------
    SHOW_STR_PROC PROC NEAR
        MOV AH, 09H
        INT 21H
        RET
    SHOW_STR_PROC ENDP

CODE ENDS
END START