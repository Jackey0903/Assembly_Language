;=============================================================================
; 程序名称: Pong 双人对战游戏 
; 功能描述: 
;   1. 双人对战 (玩家1: W/S, 玩家2: I/K)
;   2. 按 'P' 键暂停 (演示前台暂停时，后台中断仍在运行)
;   3. 按 'ESC' 退出并驻留内存 (TSR功能)
;   4. 屏幕右上角有旋转光标，由时钟中断(INT 1Ch)在后台控制
; 开发环境: MASM 5.0, DOSBox
;=============================================================================

.model small                    ; 定义内存模式为 small (代码段和数据段各64KB)
.stack 100h                     ; 定义堆栈段大小为 256 字节 (100h)

.data                           ; 数据段开始，定义变量
    ; ===== 游戏区域参数 =====
    field_width     db 78       ; 定义字节变量：场地宽度
    field_height    db 23       ; 定义字节变量：场地高度
    
    ; ===== 球的属性 =====
    ball_x          db 40       ; 球的 X 坐标 (列)
    ball_y          db 12       ; 球的 Y 坐标 (行)
    ball_dx         db 1        ; 球 X 方向速度 (1:向右, -1:向左)
    ball_dy         db 1        ; 球 Y 方向速度 (1:向下, -1:向上)
    
    ; ===== 玩家1属性 (左侧) =====
    p1_x            db 2        ; 玩家1 球拍 X 坐标
    p1_y            db 10       ; 玩家1 球拍 Y 坐标
    p1_height       db 5        ; 玩家1 球拍高度
    p1_score        db 0        ; 玩家1 分数
    
    ; ===== 玩家2属性 (右侧) =====
    p2_x            db 77       ; 玩家2 球拍 X 坐标
    p2_y            db 10       ; 玩家2 球拍 Y 坐标
    p2_height       db 5        ; 玩家2 球拍高度
    p2_score        db 0        ; 玩家2 分数
    
    ; ===== 游戏控制参数 =====
    win_score       db 3        ; 获胜所需分数
    
    ; ===== 字符定义 =====
    char_ball       db 'O'      ; 球的显示字符
    char_paddle     db 219      ; 球拍字符 (ASCII 219 是实心方块)
    
    ; ===== 字符串消息 (以 $ 结尾) =====
    msg_title       db '=== PONG GAME === (P: Pause | ESC: Quit)', '$' ; 标题栏文本
    msg_p1_win      db 'Player 1 Wins!$'        ; P1 获胜文本
    msg_p2_win      db 'Player 2 Wins!$'        ; P2 获胜文本
    msg_pause       db '*** GAME PAUSED - Press any key ***$' ; 暂停时显示的文本
    msg_tsr_info    db 'TSR Installed. Bye!$'   ; 退出并驻留时的提示文本

.code                           ; 代码段开始
main proc                       ; 主过程开始
    mov ax, @data               ; 获取数据段地址
    mov ds, ax                  ; 将地址赋值给 DS 寄存器，初始化数据段
    
    ; ===== 1. 安装自定义中断 (核心 TSR 步骤) =====
    call install_interrupt_handler ; 调用子程序，接管系统时钟中断 INT 1Ch

    ; ===== 2. 初始化显示 =====
    mov ax, 0003h               ; AH=00h (设置模式), AL=03h (80x25 文本模式)
    int 10h                     ; 调用 BIOS 视频中断
    
    call hide_cursor            ; 调用子程序隐藏光标
    
    ; ===== 显示标题 =====
    mov dh, 0                   ; 设置行号为 0
    mov dl, 20                  ; 设置列号为 20 (居中)
    call set_cursor             ; 设置光标位置
    lea dx, msg_title           ; 加载标题字符串地址到 DX
    mov ah, 9                   ; DOS 功能号 9：打印字符串
    int 21h                     ; 调用 DOS 中断显示标题
    
    ; ===== 等待开始 =====
    mov ah, 0                   ; BIOS 功能号 0：读取键盘输入
    int 16h                     ; 等待玩家按任意键开始
    
game_loop:                      ; ===== 游戏主循环标签 =====
    call check_input            ; 1. 检查键盘输入 (含暂停和移动逻辑)
    call update_ball            ; 2. 更新球的位置和处理碰撞
    call draw_game              ; 3. 绘制游戏画面
    call delay                  ; 4. 延时 (控制游戏速度)
    
    ; ===== 检查游戏结束条件 =====
    mov al, p1_score            ; 加载玩家1分数
    cmp al, win_score           ; 比较当前分数与获胜分数
    je p1_wins                  ; 如果相等，跳转到 P1 获胜处理
    
    mov al, p2_score            ; 加载玩家2分数
    cmp al, win_score           ; 比较当前分数与获胜分数
    je p2_wins                  ; 如果相等，跳转到 P2 获胜处理
    
    jmp game_loop               ; 无条件跳转回循环开始，继续游戏

; ===== 胜负处理逻辑 =====
p1_wins:                        ; P1 获胜入口
    call show_win_msg           ; 清屏并定位光标
    lea dx, msg_p1_win          ; 加载 P1 获胜消息
    jmp show_winner_text        ; 跳转到显示文本
p2_wins:                        ; P2 获胜入口
    call show_win_msg           ; 清屏并定位光标
    lea dx, msg_p2_win          ; 加载 P2 获胜消息
show_winner_text:               ; 显示获胜文本公共入口
    mov ah, 9                   ; DOS 打印字符串功能
    int 21h                     ; 执行打印
    jmp exit_to_tsr             ; 跳转到退出驻留程序

; ===== 退出并驻留处理 =====
exit_to_tsr:
    ; 恢复屏幕并显示退出信息
    mov ax, 0003h               ; 重新设置文本模式 (清屏作用)
    int 10h                     ; 调用 BIOS
    
    lea dx, msg_tsr_info        ; 加载退出提示信息
    mov ah, 9                   ; DOS 打印功能
    int 21h                     ; 显示信息
    
    ; 执行驻留退出 (Keep Resident)
    jmp do_keep_resident        ; 跳转到代码末尾执行驻留中断
main endp                       ; 主过程结束

;========================================
; 子程序: 暂停功能 (Pause)
;========================================
pause_game proc                 ; 暂停子程序开始
    push ax                     ; 保存 AX 寄存器
    push dx                     ; 保存 DX 寄存器
    
    ; 1. 显示暂停文字
    mov dh, 12                  ; 行号 12 (屏幕中央)
    mov dl, 24                  ; 列号 24
    call set_cursor             ; 设置光标
    
    lea dx, msg_pause           ; 加载暂停提示语
    mov ah, 9                   ; DOS 打印功能
    int 21h                     ; 显示 "GAME PAUSED"
    
    ; 2. 阻塞等待按键 (关键点)
    ; 在这里等待时，主程序停止，但 INT 1Ch 中断仍在后台运行
    mov ah, 0                   ; BIOS 读取键盘功能
    int 16h                     ; 阻塞！直到按下任意键才继续执行
    
    pop dx                      ; 恢复 DX 寄存器
    pop ax                      ; 恢复 AX 寄存器
    ret                         ; 返回主程序
pause_game endp                 ; 暂停子程序结束

;========================================
; 子程序: 输入检查 (含 P 键检测)
;========================================
check_input proc                ; 输入检查子程序开始
    push ax                     ; 保存 AX
    
    mov ah, 01h                 ; BIOS 功能 1：检查键盘缓冲区状态
    int 16h                     ; 调用中断
    jz input_done               ; 如果 ZF=1 (无按键)，直接跳转到结束
    
    mov ah, 00h                 ; BIOS 功能 0：读取按键 ASCII 码
    int 16h                     ; 调用中断，AL 中存放字符
    
    cmp al, 27                  ; 比较是否是 ESC 键 (ASCII 27)
    je exit_jump                ; 如果是，跳转到退出
    
    or al, 20h                  ; 将字符转换为小写 (例如 'W' -> 'w')
    
    ; ===== 暂停键判断 =====
    cmp al, 'p'                 ; 比较是否是 'p' 键
    je do_pause                 ; 如果是，跳转到暂停逻辑
    
    ; ===== 玩家控制键判断 =====
    cmp al, 'w'                 ; 检查 P1 上
    je p1_up                    ; 跳转处理
    cmp al, 's'                 ; 检查 P1 下
    je p1_down                  ; 跳转处理
    cmp al, 'i'                 ; 检查 P2 上
    je p2_up                    ; 跳转处理
    cmp al, 'k'                 ; 检查 P2 下
    je p2_down                  ; 跳转处理
    
    jmp input_done              ; 其他按键忽略，跳到结束

do_pause:                       ; 执行暂停
    call pause_game             ; 调用暂停子程序
    jmp input_done              ; 暂停回来后结束本次输入检查

exit_jump:                      ; 退出跳转中转
    jmp exit_to_tsr             ; 跳回主程序的退出点

; --- 具体移动逻辑 ---
p1_up:                          
    cmp p1_y, 2                 ; 检查是否到达上边界
    jle input_done              ; 如果到达，不移动
    dec p1_y                    ; Y 坐标减 1 (向上)
    jmp input_done
p1_down:
    mov al, p1_y                ; 取当前 Y
    add al, p1_height           ; 加上球拍高度
    cmp al, field_height        ; 检查是否到达下边界
    jge input_done              ; 如果到达，不移动
    inc p1_y                    ; Y 坐标加 1 (向下)
    jmp input_done
p2_up:
    cmp p2_y, 2                 ; 同上，P2 逻辑
    jle input_done
    dec p2_y
    jmp input_done
p2_down:
    mov al, p2_y                ; 同上，P2 逻辑
    add al, p2_height
    cmp al, field_height
    jge input_done
    inc p2_y
    jmp input_done

input_done:                     ; 输入处理结束标签
    pop ax                      ; 恢复 AX
    ret                         ; 返回
check_input endp                ; 子程序结束

;========================================
; 子程序: 球的移动与逻辑
;========================================
update_ball proc                ; 更新球子程序开始
    ; --- 更新 X 坐标 ---
    mov al, ball_x              ; 取球 X
    add al, ball_dx             ; 加上 X 速度
    mov ball_x, al              ; 存回
    ; --- 更新 Y 坐标 ---
    mov al, ball_y              ; 取球 Y
    add al, ball_dy             ; 加上 Y 速度
    mov ball_y, al              ; 存回
    
    ; --- Y轴墙壁碰撞 ---
    cmp ball_y, 2               ; 检查上墙壁
    jle bounce_y                ; 撞墙则反弹
    mov al, ball_y              
    cmp al, field_height        ; 检查下墙壁
    jge bounce_y                ; 撞墙则反弹
    jmp check_paddles           ; 没撞墙，检查球拍
bounce_y:
    neg ball_dy                 ; Y 速度取反 (1变-1, -1变1)
    mov al, ball_y              ; 防止卡墙修正
    add al, ball_dy             
    mov ball_y, al
    
check_paddles:
    ; --- 检查 P1 (左侧) ---
    cmp ball_x, 3               ; 球在 P1 攻击范围内吗？
    jg check_p2                 ; 如果 >3，去检查 P2
    cmp ball_x, 1               ; 球是否已经漏过去了？
    jl score_check              ; 如果 <1，可能得分了
    mov al, ball_y              ; 检查 Y 是否击中球拍
    cmp al, p1_y                ; 比球拍顶端高？
    jl score_check              ; 是，没接住
    mov bl, p1_y
    add bl, p1_height
    cmp al, bl                  ; 比球拍底端低？
    jg score_check              ; 是，没接住
    mov ball_dx, 1              ; 接住了！X 速度设为向右 (1)
    jmp update_ret              ; 完成更新
    
check_p2:
    ; --- 检查 P2 (右侧) ---
    cmp ball_x, 76              ; 球在 P2 攻击范围内吗？
    jl update_ret               ; 没到，直接返回
    cmp ball_x, 78              ; 是否漏过去了？
    jg score_check              ; 是，可能得分
    mov al, ball_y              ; 检查 Y 碰撞
    cmp al, p2_y
    jl score_check
    mov bl, p2_y
    add bl, p2_height
    cmp al, bl
    jg score_check
    mov ball_dx, -1             ; 接住了！X 速度设为向左 (-1)
    jmp update_ret
    
score_check:                    ; --- 得分判定 ---
    cmp ball_x, 0               ; 左侧出界？
    jle p2_sc                   ; P2 得分
    cmp ball_x, 79              ; 右侧出界？
    jge p1_sc                   ; P1 得分
    jmp update_ret              ; 没出界，返回
p1_sc:
    inc p1_score                ; P1 分数 +1
    call reset_ball             ; 重置球
    jmp update_ret
p2_sc:
    inc p2_score                ; P2 分数 +1
    call reset_ball             ; 重置球
    
update_ret:                     
    ret                         ; 返回
update_ball endp

reset_ball proc                 ; 重置球位置子程序
    mov ball_x, 40              ; 设置 X 为中心
    mov ball_y, 12              ; 设置 Y 为中心
    neg ball_dx                 ; 改变发球方向
    ret
reset_ball endp

;========================================
; 子程序: 绘图
;========================================
draw_game proc                  ; 绘图子程序开始
    call clear_screen_fast      ; 快速清屏
    
    ; --- 绘制分数 ---
    mov dh, 1                   ; 第 1 行
    mov dl, 35                  ; 第 35 列
    call set_cursor             ; 定位
    mov al, p1_score            ; 取 P1 分数
    add al, '0'                 ; 转 ASCII 码
    call print_char             ; 打印
    mov al, ':'                 
    call print_char             ; 打印冒号
    mov al, p2_score            ; 取 P2 分数
    add al, '0'
    call print_char             ; 打印
    
    ; --- 绘制 P1 球拍 ---
    mov bl, p1_height           ; 循环计数：球拍高度
    mov bh, 0                   ; 偏移量
dp1:                            ; 循环开始
    mov dh, p1_y                
    add dh, bh                  ; 计算当前行号
    mov dl, p1_x                ; 取 X 坐标
    call set_cursor             ; 定位
    mov al, char_paddle         ; 取球拍字符
    call print_char             ; 打印
    inc bh                      ; 偏移 +1
    dec bl                      ; 计数 -1
    jnz dp1                     ; 不为 0 继续循环
    
    ; --- 绘制 P2 球拍 --- (同上)
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
    
    ; --- 绘制球 ---
    mov dh, ball_y              
    mov dl, ball_x
    call set_cursor             ; 定位到球的位置
    mov al, char_ball           ; 取球字符
    call print_char             ; 打印
    ret                         ; 返回
draw_game endp

;========================================
; 辅助显示功能子程序
;========================================
show_win_msg proc               ; 获胜界面准备
    call clear_screen_fast      ; 清屏
    mov dh, 12                  ; 居中
    mov dl, 32
    call set_cursor
    ret
show_win_msg endp

clear_screen_fast proc          ; 快速清屏 (卷屏法)
    push ax
    push bx
    push cx
    push dx
    mov ax, 0600h               ; AH=06h 卷屏功能, AL=0 全屏
    mov bh, 07h                 ; 黑底白字属性
    mov cx, 0100h               ; 左上角 (1,0)
    mov dx, 184Fh               ; 右下角 (24,79)
    int 10h                     ; 执行 BIOS 中断
    pop dx
    pop cx
    pop bx
    pop ax
    ret
clear_screen_fast endp

set_cursor proc                 ; 设置光标位置
    mov ah, 2                   ; BIOS 功能 2
    mov bh, 0                   ; 页号 0
    int 10h                     ; 执行
    ret
set_cursor endp

print_char proc                 ; 打印字符
    mov ah, 0Eh                 ; BIOS 电传打字机模式
    mov bh, 0                   ; 页号 0
    int 10h                     ; 执行
    ret
print_char endp

hide_cursor proc                ; 隐藏光标
    mov ah, 1                   ; BIOS 设置光标形状
    mov ch, 32                  ; 起始行设为 32 (超出范围即隐藏)
    int 10h                     ; 执行
    ret
hide_cursor endp

delay proc                      ; 延时子程序
    push cx
    push dx
    mov cx, 2                   ; 外层循环次数 (控制总体快慢)
d_out:
    mov dx, 10000               ; 内层循环次数
d_in:
    dec dx                      ; DX 减 1
    jnz d_in                    ; 不为 0 跳转
    loop d_out                  ; 外层循环
    pop dx
    pop cx
    ret
delay endp

;=============================================================================
; TSR (驻留程序) 核心代码区域 
; 注意：这里的变量放在代码段(.code)，因为中断时无法访问数据段(.data)
;=============================================================================

; 定义中断所需的变量 (在代码段中)
tsr_old1c_off   dw 0            ; 保存旧中断向量的偏移地址
tsr_old1c_seg   dw 0            ; 保存旧中断向量的段地址
tsr_spin_idx    db 0            ; 旋转动画索引 (0-3)
tsr_spin_chars  db '|/-\'       ; 旋转字符表

; ===== 自定义中断处理程序 (Timer Handler) =====
timer_handler proc far          ; 必须定义为 FAR 过程
    push ax                     ; 保护现场：保存寄存器
    push bx
    push ds
    push es
    push di
    pushf                       ; 保存标志位

    ; === 关键步骤：设置 DS 指向 CS ===
    ; 因为中断发生时，我们不知道 DS 指向哪里(可能是 DOS，可能是其他程序)
    ; 我们的变量(tsr_spin_idx)在代码段，所以必须让 DS = CS
    push cs
    pop ds                      
    
    ; === 直接写显存 (Direct Video Memory Access) ===
    ; 即使游戏主逻辑暂停，这里依然每秒运行 18.2 次
    mov ax, 0B800h              ; 彩色文本模式显存段地址
    mov es, ax                  ; 赋值给 ES 寄存器
    mov di, 158                 ; 偏移量：第0行第79列 (79 * 2 = 158)
    
    ; 计算当前要显示的旋转字符
    mov al, tsr_spin_idx        ; 加载索引
    and al, 3                   ; 只保留低2位 (保证结果在 0-3 之间)
    mov bx, offset tsr_spin_chars ; 加载字符表地址
    xlat                        ; 查表指令: AL = [BX + AL]
    
    ; 写入屏幕
    mov ah, 0CFh                ; 属性：闪烁红色背景(C)，亮白色文字(F)
    stosw                       ; 将 AX (字符+属性) 写入 ES:DI
    
    ; 更新索引以便下次显示下一个字符
    inc tsr_spin_idx            

    ; === 恢复现场 ===
    popf                        ; 恢复标志位
    pop di
    pop es
    pop ds
    pop bx
    pop ax
    
    ; === 链接旧中断 ===
    ; 跳转去执行系统原来的中断程序，保证系统计时准确
    jmp dword ptr cs:[tsr_old1c_off] 
timer_handler endp

; ===== 安装中断子程序 =====
install_interrupt_handler proc
    push ax
    push bx
    push dx
    push ds
    push es
    
    ; 1. 获取系统原有的 1Ch 中断向量
    mov ax, 351Ch               ; DOS 功能 35h：获取中断向量
    int 21h                     ; 返回：ES:BX = 原向量
    mov word ptr cs:[tsr_old1c_seg], es ; 保存段地址到变量
    mov word ptr cs:[tsr_old1c_off], bx ; 保存偏移地址到变量
    
    ; 2. 设置新的中断向量指向 timer_handler
    push cs
    pop ds                      ; 让 DS 指向代码段 (因为 handler 在代码段)
    mov dx, offset timer_handler ; DX = 新处理程序偏移地址
    mov ax, 251Ch               ; DOS 功能 25h：设置中断向量
    int 21h                     ; 执行设置
    
    pop es
    pop ds
    pop dx
    pop bx
    pop ax
    ret
install_interrupt_handler endp

; ===== 驻留并退出标签 =====
do_keep_resident label near
    ; 计算需要驻留的内存大小 (Paragraphs)
    mov dx, offset resident_end ; 获取代码结束位置的偏移量
    mov cl, 4                   ; 准备右移 4 位 (相当于除以 16)
    shr dx, cl                  ; 转换为段落数 (1段落=16字节)
    add dx, 11h                 ; 加上 PSP (10h) 和一点安全空间 (1h)
    
    mov ax, 3100h               ; DOS 功能 31h：结束并驻留
    int 21h                     ; 调用 DOS，程序结束但留在内存中

resident_end label byte         ; 标记代码段结束位置

end main                        ; 程序结束，入口点 main