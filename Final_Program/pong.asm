;========================================
; 程序名称: Pong 双人对战游戏
; 功能描述: 文本模式下的经典乒乓球游戏
; 开发环境: MASM 5.0, DOSBox
; 作者: [你的姓名]
; 日期: 2025年12月
;========================================

.model small                    ; 使用小内存模型(代码段和数据段各64KB)
.stack 100h                     ; 分配256字节的堆栈空间

.data                           ; 数据段开始
    ; ===== 游戏区域参数 =====
    field_width     db 78       ; 游戏场地宽度(字符数)
    field_height    db 23       ; 游戏场地高度(字符数)
    
    ; ===== 球的属性 =====
    ball_x          db 40       ; 球的X坐标(横向位置)
    ball_y          db 12       ; 球的Y坐标(纵向位置)
    ball_dx         db 1        ; 球X方向速度(1=向右, -1=向左)
    ball_dy         db 1        ; 球Y方向速度(1=向下, -1=向上)
    
    ; ===== 玩家1属性(左侧球拍) =====
    p1_x            db 2        ; 玩家1球拍X坐标(固定在左侧)
    p1_y            db 10       ; 玩家1球拍Y坐标(可上下移动)
    p1_height       db 5        ; 玩家1球拍高度(占5个字符)
    p1_score        db 0        ; 玩家1当前分数
    
    ; ===== 玩家2属性(右侧球拍) =====
    p2_x            db 77       ; 玩家2球拍X坐标(固定在右侧)
    p2_y            db 10       ; 玩家2球拍Y坐标(可上下移动)
    p2_height       db 5        ; 玩家2球拍高度(占5个字符)
    p2_score        db 0        ; 玩家2当前分数
    
    ; ===== 游戏控制参数 =====
    win_score       db 3        ; 获胜所需分数(先得3分者获胜)
    game_speed      dw 15000    ; 游戏速度(延时循环次数,越大越慢)
    
    ; ===== 显示字符定义 =====
    char_ball       db 'O'      ; 球的显示字符
    char_paddle     db 219      ; 球拍字符(ASCII 219=实心方块█)
    char_border     db '-'      ; 边框字符
    char_empty      db ' '      ; 空格(用于清除)
    
    ; ===== 提示信息字符串 =====
    msg_title       db '=== PONG GAME === (P1: W/S | P2: I/K)', '$'  ; 游戏标题
    msg_p1_win      db 'Player 1 Wins!$'       ; 玩家1获胜提示
    msg_p2_win      db 'Player 2 Wins!$'       ; 玩家2获胜提示
    msg_press_key   db 'Press any key to exit...$'  ; 退出提示

.code                           ; 代码段开始
main proc                       ; 主程序开始
    mov ax, @data               ; 将数据段地址加载到AX
    mov ds, ax                  ; 设置DS寄存器指向数据段
    
    ; ===== 初始化显示模式 =====
    mov ax, 0003h               ; AH=00h(设置视频模式), AL=03h(80x25文本模式)
    int 10h                     ; 调用BIOS视频服务,清屏并初始化
    
    ; ===== 隐藏光标 =====
    mov ah, 1                   ; AH=1: 设置光标形状功能
    mov ch, 32                  ; CH=32: 将光标起始行设为32(超出范围,光标不可见)
    int 10h                     ; 调用BIOS视频服务
    
    ; ===== 显示游戏标题 =====
    mov dh, 0                   ; DH=行号(第0行,屏幕顶部)
    mov dl, 20                  ; DL=列号(第20列,居中显示)
    call set_cursor             ; 调用设置光标位置子程序
    lea dx, msg_title           ; 将标题字符串地址加载到DX
    mov ah, 9                   ; AH=9: DOS打印字符串功能
    int 21h                     ; 调用DOS服务,显示字符串
    
    ; ===== 等待玩家按键开始游戏 =====
    mov ah, 0                   ; AH=0: 等待键盘输入(阻塞式)
    int 16h                     ; 调用BIOS键盘服务,等待按键
    
game_loop:                      ; ===== 游戏主循环 =====
    ; 步骤1: 检查键盘输入
    call check_input            ; 调用键盘检测子程序(检查W/S/I/K/ESC)
    
    ; 步骤2: 更新球的位置
    call update_ball            ; 调用球移动子程序(处理碰撞和得分)
    
    ; 步骤3: 绘制游戏画面
    call draw_game              ; 调用绘图子程序(显示球拍、球和分数)
    
    ; 步骤4: 延时控制游戏速度
    call delay                  ; 调用延时子程序(控制帧率)
    
    ; ===== 检查游戏是否结束 =====
    mov al, p1_score            ; 将玩家1分数加载到AL
    cmp al, win_score           ; 比较是否达到获胜分数
    je p1_wins                  ; 如果相等,跳转到玩家1获胜处理
    
    mov al, p2_score            ; 将玩家2分数加载到AL
    cmp al, win_score           ; 比较是否达到获胜分数
    je p2_wins                  ; 如果相等,跳转到玩家2获胜处理
    
    jmp game_loop               ; 无条件跳转,继续游戏循环

p1_wins:                        ; ===== 玩家1获胜处理 =====
    call show_win_msg           ; 调用显示获胜界面子程序
    lea dx, msg_p1_win          ; 加载玩家1获胜消息地址
    jmp show_winner_text        ; 跳转到显示获胜者文本

p2_wins:                        ; ===== 玩家2获胜处理 =====
    call show_win_msg           ; 调用显示获胜界面子程序
    lea dx, msg_p2_win          ; 加载玩家2获胜消息地址
    
show_winner_text:               ; ===== 显示获胜者文本 =====
    mov ah, 9                   ; AH=9: DOS打印字符串功能
    int 21h                     ; 调用DOS服务,显示获胜者
    jmp game_end                ; 跳转到游戏结束处理

game_end:                       ; ===== 游戏结束处理 =====
    ; 显示退出提示
    mov dh, 14                  ; DH=行号(第14行)
    mov dl, 30                  ; DL=列号(第30列)
    call set_cursor             ; 设置光标位置
    lea dx, msg_press_key       ; 加载退出提示消息地址
    mov ah, 9                   ; AH=9: 打印字符串
    int 21h                     ; 显示提示
    
    ; 等待按键退出
    mov ah, 0                   ; AH=0: 等待键盘输入
    int 16h                     ; 等待玩家按任意键
    
    ; 恢复屏幕和光标
    mov ax, 0003h               ; 重新设置文本模式(清屏)
    int 10h                     ; 调用BIOS视频服务
    
    ; 退出程序
    mov ax, 4C00h               ; AH=4Ch: DOS终止程序, AL=00h(返回码0)
    int 21h                     ; 调用DOS服务,退出到操作系统
main endp                       ; 主程序结束

;========================================
; 子程序: show_win_msg
; 功能: 显示获胜界面(清屏并居中光标)
; 输入: 无
; 输出: 无
; 修改: 无
;========================================
show_win_msg proc
    call clear_screen_fast      ; 调用快速清屏子程序
    mov dh, 12                  ; DH=行号(第12行,屏幕中央)
    mov dl, 32                  ; DL=列号(第32列,居中)
    call set_cursor             ; 设置光标位置
    ret                         ; 返回调用处
show_win_msg endp

;========================================
; 子程序: clear_screen_fast
; 功能: 使用卷屏功能快速清屏
; 输入: 无
; 输出: 无
; 修改: AX, BX, CX, DX
;========================================
clear_screen_fast proc
    push ax                     ; 保存AX寄存器
    push bx                     ; 保存BX寄存器
    push cx                     ; 保存CX寄存器
    push dx                     ; 保存DX寄存器
    
    mov ax, 0600h               ; AH=06h(向上卷屏), AL=0(清空整个窗口)
    mov bh, 07h                 ; BH=07h(属性: 黑底白字)
    mov cx, 0100h               ; CH=1(起始行), CL=0(起始列) - 保留第0行
    mov dx, 184Fh               ; DH=24(结束行), DL=79(结束列)
    int 10h                     ; 调用BIOS视频服务,执行卷屏
    
    pop dx                      ; 恢复DX寄存器
    pop cx                      ; 恢复CX寄存器
    pop bx                      ; 恢复BX寄存器
    pop ax                      ; 恢复AX寄存器
    ret                         ; 返回调用处
clear_screen_fast endp

;========================================
; 子程序: check_input
; 功能: 检查键盘输入并更新球拍位置
; 输入: 无
; 输出: 无
; 按键: W/S(玩家1上/下), I/K(玩家2上/下), ESC(退出)
;========================================
check_input proc
    push ax                     ; 保存AX寄存器
    
    ; ===== 检查键盘缓冲区 =====
    mov ah, 01h                 ; AH=01h: 检查键盘缓冲区(非阻塞)
    int 16h                     ; 调用BIOS键盘服务
    jz input_done               ; ZF=1表示无按键,跳转到input_done
    
    ; ===== 读取按键 =====
    mov ah, 00h                 ; AH=00h: 读取键盘(并清除缓冲区)
    int 16h                     ; 调用BIOS键盘服务,AL=ASCII码
    
    ; ===== 检查ESC键(退出) =====
    cmp al, 27                  ; 比较AL是否为27(ESC的ASCII码)
    je exit_game_jump           ; 如果是ESC,跳转到退出游戏
    
    ; ===== 转换为小写(统一处理大小写) =====
    or al, 20h                  ; 将AL的第5位设为1(大写转小写)
    
    ; ===== 检查玩家1控制键 =====
    cmp al, 'w'                 ; 比较是否为'w'
    je p1_up                    ; 是'w',跳转到玩家1向上移动
    cmp al, 's'                 ; 比较是否为's'
    je p1_down                  ; 是's',跳转到玩家1向下移动
    
    ; ===== 检查玩家2控制键 =====
    cmp al, 'i'                 ; 比较是否为'i'
    je p2_up                    ; 是'i',跳转到玩家2向上移动
    cmp al, 'k'                 ; 比较是否为'k'
    je p2_down                  ; 是'k',跳转到玩家2向下移动
    
    jmp input_done              ; 其他按键,跳转到输入完成

exit_game_jump:                 ; ===== 退出游戏跳转 =====
    jmp game_end                ; 跳转到游戏结束处理

p1_up:                          ; ===== 玩家1向上移动 =====
    cmp p1_y, 2                 ; 比较Y坐标是否<=2(上边界,留出标题栏)
    jle input_done              ; 如果<=2,已到边界,不移动
    dec p1_y                    ; Y坐标减1(向上移动)
    jmp input_done              ; 跳转到输入完成

p1_down:                        ; ===== 玩家1向下移动 =====
    mov al, p1_y                ; 将Y坐标加载到AL
    add al, p1_height           ; 加上球拍高度(计算球拍底部位置)
    cmp al, field_height        ; 比较是否>=场地高度(下边界)
    jge input_done              ; 如果>=场地高度,已到边界,不移动
    inc p1_y                    ; Y坐标加1(向下移动)
    jmp input_done              ; 跳转到输入完成

p2_up:                          ; ===== 玩家2向上移动 =====
    cmp p2_y, 2                 ; 比较Y坐标是否<=2(上边界)
    jle input_done              ; 如果<=2,已到边界,不移动
    dec p2_y                    ; Y坐标减1(向上移动)
    jmp input_done              ; 跳转到输入完成

p2_down:                        ; ===== 玩家2向下移动 =====
    mov al, p2_y                ; 将Y坐标加载到AL
    add al, p2_height           ; 加上球拍高度
    cmp al, field_height        ; 比较是否>=场地高度
    jge input_done              ; 如果>=场地高度,已到边界,不移动
    inc p2_y                    ; Y坐标加1(向下移动)
    jmp input_done              ; 跳转到输入完成

input_done:                     ; ===== 输入处理完成 =====
    pop ax                      ; 恢复AX寄存器
    ret                         ; 返回调用处
check_input endp

;========================================
; 子程序: update_ball
; 功能: 更新球的位置,处理碰撞和得分
; 输入: 无
; 输出: 无
; 修改: AL, BL
;========================================
update_ball proc
    ; ===== 更新X坐标(横向移动) =====
    mov al, ball_x              ; 将球X坐标加载到AL
    add al, ball_dx             ; 加上X方向速度(1或-1)
    mov ball_x, al              ; 保存新的X坐标
    
    ; ===== 更新Y坐标(纵向移动) =====
    mov al, ball_y              ; 将球Y坐标加载到AL
    add al, ball_dy             ; 加上Y方向速度(1或-1)
    mov ball_y, al              ; 保存新的Y坐标
    
    ; ===== 检查Y轴碰撞(上下墙壁) =====
    cmp ball_y, 2               ; 比较Y坐标是否<=2(顶部墙壁,留出标题栏)
    jle bounce_y                ; 如果<=2,发生碰撞,跳转到Y轴反弹
    mov al, ball_y              ; 重新加载Y坐标
    cmp al, field_height        ; 比较Y坐标是否>=场地高度(底部墙壁)
    jge bounce_y                ; 如果>=场地高度,发生碰撞,跳转到Y轴反弹
    jmp check_paddles_logic     ; 无碰撞,跳转到检查球拍碰撞

bounce_y:                       ; ===== Y轴反弹处理 =====
    neg ball_dy                 ; 反转Y方向速度(1变-1, -1变1)
    ; 防止球卡在墙里,强制推出
    mov al, ball_y              ; 加载Y坐标
    add al, ball_dy             ; 加上反转后的速度
    mov ball_y, al              ; 保存修正后的Y坐标

check_paddles_logic:            ; ===== 检查球拍碰撞 =====
    ; ===== 检查玩家1球拍(左侧) =====
    cmp ball_x, 3               ; 比较X坐标是否<=3(P1区域)
    jg check_p2_logic           ; 如果>3,球在右侧,跳转检查P2
    
    cmp ball_x, 1               ; 比较X坐标是否<1
    jl check_scoring            ; 如果<1,球已出界,跳转到得分检查
    
    ; 球在P1区域,检查Y坐标是否在球拍范围内
    mov al, ball_y              ; 加载球Y坐标
    cmp al, p1_y                ; 比较是否<球拍顶部
    jl check_scoring            ; 如果<球拍顶部,未击中,跳转得分检查
    mov bl, p1_y                ; 加载球拍Y坐标到BL
    add bl, p1_height           ; 加上球拍高度(计算球拍底部)
    cmp al, bl                  ; 比较球Y是否>球拍底部
    jg check_scoring            ; 如果>球拍底部,未击中,跳转得分检查
    
    ; 击中玩家1球拍
    mov ball_dx, 1              ; 设置X速度为1(向右反弹)
    jmp update_done             ; 跳转到更新完成

check_p2_logic:                 ; ===== 检查玩家2球拍(右侧) =====
    cmp ball_x, 76              ; 比较X坐标是否>=76(P2区域)
    jl update_done              ; 如果<76,球在中间,无碰撞,跳转完成
    
    cmp ball_x, 78              ; 比较X坐标是否>78
    jg check_scoring            ; 如果>78,球已出界,跳转得分检查
    
    ; 球在P2区域,检查Y坐标
    mov al, ball_y              ; 加载球Y坐标
    cmp al, p2_y                ; 比较是否<球拍顶部
    jl check_scoring            ; 如果<球拍顶部,未击中
    mov bl, p2_y                ; 加载球拍Y坐标到BL
    add bl, p2_height           ; 加上球拍高度
    cmp al, bl                  ; 比较球Y是否>球拍底部
    jg check_scoring            ; 如果>球拍底部,未击中
    
    ; 击中玩家2球拍
    mov ball_dx, -1             ; 设置X速度为-1(向左反弹)
    jmp update_done             ; 跳转到更新完成

check_scoring:                  ; ===== 检查得分 =====
    cmp ball_x, 0               ; 比较X坐标是否<=0(左侧出界)
    jle p2_scores               ; 如果<=0,玩家2得分
    cmp ball_x, 79              ; 比较X坐标是否>=79(右侧出界)
    jge p1_scores               ; 如果>=79,玩家1得分
    jmp update_done             ; 球未出界,跳转完成

p1_scores:                      ; ===== 玩家1得分 =====
    inc p1_score                ; 玩家1分数加1
    call reset_ball             ; 调用重置球位置子程序
    jmp update_done             ; 跳转完成

p2_scores:                      ; ===== 玩家2得分 =====
    inc p2_score                ; 玩家2分数加1
    call reset_ball             ; 调用重置球位置子程序

update_done:                    ; ===== 更新完成 =====
    ret                         ; 返回调用处
update_ball endp

;========================================
; 子程序: reset_ball
; 功能: 重置球到场地中央
; 输入: 无
; 输出: 无
; 修改: ball_x, ball_y, ball_dx
;========================================
reset_ball proc
    mov ball_x, 40              ; 将球X坐标设为40(场地中央)
    mov ball_y, 12              ; 将球Y坐标设为12(场地中央)
    neg ball_dx                 ; 反转X速度(让球向失分方发球)
    ret                         ; 返回调用处
reset_ball endp

;========================================
; 子程序: draw_game
; 功能: 绘制完整游戏画面(球拍、球、分数)
; 输入: 无
; 输出: 无
; 修改: AL, BL, BH, DH, DL
;========================================
draw_game proc
    call clear_screen_fast      ; 调用快速清屏(清除上一帧)
    
    ; ===== 绘制分数显示 =====
    mov dh, 1                   ; DH=行号(第1行)
    mov dl, 35                  ; DL=列号(第35列,居中)
    call set_cursor             ; 设置光标位置
    mov al, p1_score            ; 加载玩家1分数
    add al, '0'                 ; 转换为ASCII字符('0'的ASCII码是48)
    call print_char             ; 调用打印字符子程序
    mov al, ':'                 ; 加载冒号字符
    call print_char             ; 打印冒号
    mov al, p2_score            ; 加载玩家2分数
    add al, '0'                 ; 转换为ASCII字符
    call print_char             ; 打印玩家2分数
    
    ; ===== 绘制玩家1球拍 =====
    mov bl, p1_height           ; BL=球拍高度(循环计数器)
    mov bh, 0                   ; BH=0(当前偏移量)
draw_p1_loop:                   ; 玩家1球拍绘制循环
    mov dh, p1_y                ; 加载球拍Y坐标
    add dh, bh                  ; 加上当前偏移(绘制球拍的每一行)
    mov dl, p1_x                ; 加载球拍X坐标
    call set_cursor             ; 设置光标到球拍位置
    mov al, char_paddle         ; 加载球拍字符(实心块)
    call print_char             ; 打印球拍字符
    inc bh                      ; 偏移量加1(移到下一行)
    dec bl                      ; 计数器减1
    jnz draw_p1_loop            ; 如果计数器不为0,继续循环
    
    ; ===== 绘制玩家2球拍 =====
    mov bl, p2_height           ; BL=球拍高度
    mov bh, 0                   ; BH=0(重置偏移量)
draw_p2_loop:                   ; 玩家2球拍绘制循环
    mov dh, p2_y                ; 加载球拍Y坐标
    add dh, bh                  ; 加上当前偏移
    mov dl, p2_x                ; 加载球拍X坐标
    call set_cursor             ; 设置光标位置
    mov al, char_paddle         ; 加载球拍字符
    call print_char             ; 打印球拍字符
    inc bh                      ; 偏移量加1
    dec bl                      ; 计数器减1
    jnz draw_p2_loop            ; 如果计数器不为0,继续循环
    
    ; ===== 绘制球 =====
    mov dh, ball_y              ; 加载球Y坐标
    mov dl, ball_x              ; 加载球X坐标
    call set_cursor             ; 设置光标到球的位置
    mov al, char_ball           ; 加载球字符('O')
    call print_char             ; 打印球字符
    
    ret                         ; 返回调用处
draw_game endp

;========================================
; 子程序: set_cursor
; 功能: 设置光标位置
; 输入: DH=行号(0-24), DL=列号(0-79)
; 输出: 无
; 修改: AH, BH
;========================================
set_cursor proc
    mov ah, 2                   ; AH=2: BIOS设置光标位置功能
    mov bh, 0                   ; BH=0: 页号(第0页)
    int 10h                     ; 调用BIOS视频服务
    ret                         ; 返回调用处
set_cursor endp

;========================================
; 子程序: print_char
; 功能: 在当前光标位置打印字符
; 输入: AL=要打印的字符
; 输出: 无
; 修改: AH, BH
;========================================
print_char proc
    mov ah, 0Eh                 ; AH=0Eh: BIOS显示字符功能(TTY模式)
    mov bh, 0                   ; BH=0: 页号(第0页)
    int 10h                     ; 调用BIOS视频服务,显示AL中的字符
    ret                         ; 返回调用处
print_char endp

;========================================
; 子程序: delay
; 功能: 延时控制游戏速度(帧率)
; 输入: 无
; 输出: 无
; 修改: CX, DX
;========================================
delay proc
    push cx                     ; 保存CX寄存器
    push dx                     ; 保存DX寄存器
    
    ; ===== 外层循环(控制总延时) =====
    mov cx, 3                   ; CX=3: 外层循环次数(可调整游戏速度)
    
delay_outer:                    ; 外层循环开始
    mov dx, game_speed          ; DX=game_speed(内层循环次数15000)
    
delay_inner:                    ; 内层循环开始
    dec dx                      ; DX减1
    jnz delay_inner             ; 如果DX不为0,继续内层循环
    
    loop delay_outer            ; CX减1,如果不为0,继续外层循环
    
    pop dx                      ; 恢复DX寄存器
    pop cx                      ; 恢复CX寄存器
    ret                         ; 返回调用处
delay endp

end main                        ; 程序结束,入口点为main
