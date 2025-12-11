;========================================
; 程序名称: Pong 双人对战游戏 (含暂停 + TSR演示)
; 功能描述: 
;   1. 双人对战 (W/S 和 I/K)
;   2. 按 'P' 键暂停 (验证中断后台运行)
;   3. 按 'ESC' 退出并驻留内存 (TSR)
;   4. 屏幕右上角有 TSR 控制的旋转光标
; 开发环境: MASM 5.0, DOSBox
;========================================

.model small
.stack 100h

.data
    ; ===== 游戏区域参数 =====
    field_width     db 78       
    field_height    db 23       
    
    ; ===== 球的属性 =====
    ball_x          db 40       
    ball_y          db 12       
    ball_dx         db 1        
    ball_dy         db 1        
    
    ; ===== 玩家1属性 (左) =====
    p1_x            db 2        
    p1_y            db 10       
    p1_height       db 5        
    p1_score        db 0        
    
    ; ===== 玩家2属性 (右) =====
    p2_x            db 77       
    p2_y            db 10       
    p2_height       db 5        
    p2_score        db 0        
    
    ; ===== 游戏控制 =====
    win_score       db 3        
    game_speed      dw 15000    ; 游戏速度调整
    
    ; ===== 字符定义 =====
    char_ball       db 'O'      
    char_paddle     db 219      ; 实心方块
    
    ; ===== 字符串 =====
    msg_title       db '=== PONG GAME === (P: Pause | ESC: Quit)', '$' 
    msg_p1_win      db 'Player 1 Wins!$'        
    msg_p2_win      db 'Player 2 Wins!$'        
    msg_pause       db '*** GAME PAUSED - Press any key ***$' ; 暂停提示
    msg_tsr_info    db 'TSR Installed. Bye!$'

.code
main proc
    mov ax, @data
    mov ds, ax
    
    ; ===== 1. 立即安装自定义中断 (为了演示暂停时的后台运行) =====
    ; 我们在游戏开始时就 hook 1Ch 中断，这样右上角的字符就会开始转动
    call install_interrupt_handler

    ; ===== 2. 初始化显示 =====
    mov ax, 0003h               ; 80x25 文本模式
    int 10h                     
    
    call hide_cursor            ; 隐藏光标
    
    ; 显示标题
    mov dh, 0
    mov dl, 20
    call set_cursor
    lea dx, msg_title
    mov ah, 9
    int 21h
    
    ; 等待任意键开始
    mov ah, 0
    int 16h
    
game_loop:
    ; ===== 游戏主循环 =====
    call check_input            ; 检查按键 (含暂停逻辑)
    call update_ball            ; 移动球
    call draw_game              ; 绘图
    call delay                  ; 延时
    
    ; 检查分数
    mov al, p1_score
    cmp al, win_score
    je p1_wins
    
    mov al, p2_score
    cmp al, win_score
    je p2_wins
    
    jmp game_loop

; ===== 胜负处理 =====
p1_wins:
    call show_win_msg
    lea dx, msg_p1_win
    jmp show_winner_text
p2_wins:
    call show_win_msg
    lea dx, msg_p2_win
show_winner_text:
    mov ah, 9
    int 21h
    jmp exit_to_tsr

; ===== 退出处理 =====
exit_to_tsr:
    ; 恢复屏幕并显示退出信息
    mov ax, 0003h
    int 10h
    
    lea dx, msg_tsr_info
    mov ah, 9
    int 21h
    
    ; 执行驻留退出 (Keep Resident)
    jmp do_keep_resident

main endp

;========================================
; 子程序: 暂停功能
;========================================
pause_game proc
    push ax
    push dx
    
    ; 1. 显示暂停文字
    mov dh, 12                  ; 屏幕中央行
    mov dl, 24                  ; 屏幕中央列
    call set_cursor
    
    lea dx, msg_pause
    mov ah, 9
    int 21h
    
    ; 2. 阻塞等待按键 (此时游戏画面静止，但中断仍在运行)
    mov ah, 0                   ; 读取按键
    int 16h                     ; CPU在这里等待，不再执行游戏循环
    
    ; 3. 恢复画面 (清除文字最简单的方法是下一帧重绘，这里不用手动清)
    ; 返回后，主循环的 draw_game 会覆盖掉暂停文字
    
    pop dx
    pop ax
    ret
pause_game endp

;========================================
; 子程序: 输入检查 (含 P 键)
;========================================
check_input proc
    push ax
    
    mov ah, 01h                 ; 检查缓冲区
    int 16h
    jz input_done               ; 无按键则跳过
    
    mov ah, 00h                 ; 读取按键
    int 16h
    
    cmp al, 27                  ; ESC 键
    je exit_jump
    
    or al, 20h                  ; 转换为小写
    
    ; ===== 暂停键判断 =====
    cmp al, 'p'                 ; 是 'p' 吗？
    je do_pause                 ; 跳转到暂停处理
    
    ; 玩家控制键
    cmp al, 'w'
    je p1_up
    cmp al, 's'
    je p1_down
    cmp al, 'i'
    je p2_up
    cmp al, 'k'
    je p2_down
    
    jmp input_done

do_pause:
    call pause_game             ; 调用暂停子程序
    jmp input_done

exit_jump:
    jmp exit_to_tsr             ; 跳转到主程序退出点

p1_up:
    cmp p1_y, 2
    jle input_done
    dec p1_y
    jmp input_done
p1_down:
    mov al, p1_y
    add al, p1_height
    cmp al, field_height
    jge input_done
    inc p1_y
    jmp input_done
p2_up:
    cmp p2_y, 2
    jle input_done
    dec p2_y
    jmp input_done
p2_down:
    mov al, p2_y
    add al, p2_height
    cmp al, field_height
    jge input_done
    inc p2_y
    jmp input_done

input_done:
    pop ax
    ret
check_input endp

;========================================
; 游戏逻辑子程序 (移动球、绘图等)
;========================================
update_ball proc
    ; X 移动
    mov al, ball_x
    add al, ball_dx
    mov ball_x, al
    ; Y 移动
    mov al, ball_y
    add al, ball_dy
    mov ball_y, al
    
    ; Y 碰撞
    cmp ball_y, 2
    jle bounce_y
    mov al, ball_y
    cmp al, field_height
    jge bounce_y
    jmp check_paddles
bounce_y:
    neg ball_dy
    mov al, ball_y
    add al, ball_dy
    mov ball_y, al
check_paddles:
    ; P1
    cmp ball_x, 3
    jg check_p2
    cmp ball_x, 1
    jl score_check
    mov al, ball_y
    cmp al, p1_y
    jl score_check
    mov bl, p1_y
    add bl, p1_height
    cmp al, bl
    jg score_check
    mov ball_dx, 1
    jmp update_ret
check_p2:
    cmp ball_x, 76
    jl update_ret
    cmp ball_x, 78
    jg score_check
    mov al, ball_y
    cmp al, p2_y
    jl score_check
    mov bl, p2_y
    add bl, p2_height
    cmp al, bl
    jg score_check
    mov ball_dx, -1
    jmp update_ret
score_check:
    cmp ball_x, 0
    jle p2_sc
    cmp ball_x, 79
    jge p1_sc
    jmp update_ret
p1_sc:
    inc p1_score
    call reset_ball
    jmp update_ret
p2_sc:
    inc p2_score
    call reset_ball
update_ret:
    ret
update_ball endp

reset_ball proc
    mov ball_x, 40
    mov ball_y, 12
    neg ball_dx
    ret
reset_ball endp

draw_game proc
    call clear_screen_fast
    
    ; 显示分数
    mov dh, 1
    mov dl, 35
    call set_cursor
    mov al, p1_score
    add al, '0'
    call print_char
    mov al, ':'
    call print_char
    mov al, p2_score
    add al, '0'
    call print_char
    
    ; 绘制 P1
    mov bl, p1_height
    mov bh, 0
dp1:
    mov dh, p1_y
    add dh, bh
    mov dl, p1_x
    call set_cursor
    mov al, char_paddle
    call print_char
    inc bh
    dec bl
    jnz dp1
    
    ; 绘制 P2
    mov bl, p2_height
    mov bh, 0
dp2:
    mov dh, p2_y
    add dh, bh
    mov dl, p2_x
    call set_cursor
    mov al, char_paddle
    call print_char
    inc bh
    dec bl
    jnz dp2
    
    ; 绘制球
    mov dh, ball_y
    mov dl, ball_x
    call set_cursor
    mov al, char_ball
    call print_char
    ret
draw_game endp

; 辅助绘图功能
show_win_msg proc
    call clear_screen_fast
    mov dh, 12
    mov dl, 32
    call set_cursor
    ret
show_win_msg endp

clear_screen_fast proc
    push ax
    push bx
    push cx
    push dx
    mov ax, 0600h
    mov bh, 07h
    mov cx, 0100h
    mov dx, 184Fh
    int 10h
    pop dx
    pop cx
    pop bx
    pop ax
    ret
clear_screen_fast endp

set_cursor proc
    mov ah, 2
    mov bh, 0
    int 10h
    ret
set_cursor endp

print_char proc
    mov ah, 0Eh
    mov bh, 0
    int 10h
    ret
print_char endp

hide_cursor proc
    mov ah, 1
    mov ch, 32
    int 10h
    ret
hide_cursor endp

delay proc
    push cx
    push dx
    mov cx, 2           ; 调小一点让球快点
d_out:
    mov dx, 10000
d_in:
    dec dx
    jnz d_in
    loop d_out
    pop dx
    pop cx
    ret
delay endp

;========================================
; TSR 核心代码区域 (代码段内)
;========================================

; 1. 放在代码段的变量，供中断程序使用
tsr_old1c_off   dw 0
tsr_old1c_seg   dw 0
tsr_spin_idx    db 0            ; 旋转动画索引
tsr_spin_chars  db '|/-\'       ; 旋转动画字符集

; 2. 中断处理程序 (Timer Handler)
timer_handler proc far
    push ax
    push bx
    push ds
    push es
    push di
    pushf

    ; 设置 DS 指向 CS (关键!)
    push cs
    pop ds
    
    ; ===== 演示功能：直接写显存 =====
    ; 即使游戏在 pause_game 里被 int 16h 阻塞，
    ; 这个中断依然会每秒触发18.2次
    
    mov ax, 0B800h              ; 显存段地址
    mov es, ax
    mov di, 158                 ; 屏幕右上角位置 (第0行第79列 * 2字节)
    
    ; 计算旋转字符
    mov al, tsr_spin_idx
    and al, 3                   ; 只取低2位 (0-3)
    mov bx, offset tsr_spin_chars
    xlat                        ; AL = spin_chars[AL]
    
    ; 写入屏幕 (闪烁红色背景，白色文字，确保显眼)
    mov ah, 0CFh                
    stosw                       ; 将 AX 写入 ES:DI
    
    ; 更新索引
    inc tsr_spin_idx

    popf
    pop di
    pop es
    pop ds
    pop bx
    pop ax
    
    ; 跳转回旧的中断处理程序 (链接中断)
    jmp dword ptr cs:[tsr_old1c_off]
timer_handler endp

; 3. 安装中断 (在游戏开始时调用)
install_interrupt_handler proc
    push ax
    push bx
    push dx
    push ds
    push es
    
    ; 获取原中断向量 1Ch
    mov ax, 351Ch
    int 21h
    mov word ptr cs:[tsr_old1c_seg], es
    mov word ptr cs:[tsr_old1c_off], bx
    
    ; 设置新中断向量
    push cs
    pop ds
    mov dx, offset timer_handler
    mov ax, 251Ch
    int 21h
    
    pop es
    pop ds
    pop dx
    pop bx
    pop ax
    ret
install_interrupt_handler endp

; 4. 驻留并退出 (在 ESC 时调用)
do_keep_resident label near
    ; 计算驻留大小
    mov dx, offset resident_end
    mov cl, 4
    shr dx, cl
    add dx, 11h                 ; PSP + 安全余量
    
    mov ax, 3100h               ; 驻留退出功能调用
    int 21h

resident_end label byte

end main