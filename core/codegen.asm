align 8
net_listen_template:
    rol ax, 8
    push rax
    mov eax, 41
    mov edi, 2
    mov esi, 1
    xor edx, edx
    syscall
    push rax
    push 1
    mov r8, rsp
    mov r10d, 4
    mov edx, 2
    mov esi, 1
    mov rdi, [rsp + 8]
    mov eax, 54
    syscall
    pop rcx
    sub rsp, 16
    mov word [rsp], 2
    mov cx, word [rsp + 24]
    mov word [rsp + 2], cx
    mov dword [rsp + 4], 0
    mov qword [rsp + 8], 0
    mov rdi, [rsp + 16]
    mov rsi, rsp
    mov edx, 16
    mov eax, 49
    syscall
    add rsp, 16
    mov rdi, [rsp]
    mov esi, 128
    mov eax, 50
    syscall
    pop rax
    pop rcx
net_listen_template_end:
NET_LISTEN_SIZE = net_listen_template_end - net_listen_template

align 8

is_hex_char:
    xor ah, ah
    cmp al, '0'
    jb .not_hex
    cmp al, '9'
    jbe .is_hex
    cmp al, 'A'
    jb .not_hex
    cmp al, 'F'
    jbe .is_hex
    cmp al, 'a'
    jb .not_hex
    cmp al, 'f'
    ja .not_hex
.is_hex:
    mov ah, 1
.not_hex:
    ret

get_addr_len_disp:
    test r9, r9
    jnz .gald_disp
    cmp r8b, 5
    je .gald_disp8
    cmp r8b, 4
    je .gald_rsp0
    mov eax, 1
    ret
.gald_rsp0:
    mov eax, 2
    ret
.gald_disp:
    cmp r9, 127
    jg .gald_disp32
    cmp r9, -128
    jl .gald_disp32
.gald_disp8:
    cmp r8b, 4
    je .gald_rsp8
    mov eax, 2
    ret
.gald_rsp8:
    mov eax, 3
    ret
.gald_disp32:
    cmp r8b, 4
    je .gald_rsp32
    mov eax, 5
    ret
.gald_rsp32:
    mov eax, 6
    ret

emit_modrm_addr_disp:
    test r9, r9
    jnz .emad_disp
    cmp r8b, 5
    je .emad_disp8
    cmp r8b, 4
    je .emad_rsp0

    or al, r8b
    mov byte [r13], al
    inc r13
    ret

.emad_rsp0:
    or al, 0x04
    mov byte [r13], al
    inc r13
    mov byte [r13], 0x24
    inc r13
    ret

.emad_disp:
    cmp r9, 127
    jg .emad_disp32
    cmp r9, -128
    jl .emad_disp32

.emad_disp8:
    or al, 0x40
    cmp r8b, 4
    je .emad_rsp8
    or al, r8b
    mov byte [r13], al
    inc r13
    mov byte [r13], r9b
    inc r13
    ret

.emad_rsp8:
    or al, 0x04
    mov byte [r13], al
    inc r13
    mov byte [r13], 0x24
    inc r13
    mov byte [r13], r9b
    inc r13
    ret

.emad_disp32:
    or al, 0x80
    cmp r8b, 4
    je .emad_rsp32
    or al, r8b
    mov byte [r13], al
    inc r13
    mov dword [r13], r9d
    add r13, 4
    ret

.emad_rsp32:
    or al, 0x04
    mov byte [r13], al
    inc r13
    mov byte [r13], 0x24
    inc r13
    mov dword [r13], r9d
    add r13, 4
    ret

decode_hex_byte:
    push rax
    mov dl, ah
    cmp dl, '9'
    jbe .h1
    cmp dl, 'F'
    jbe .h1A
    sub dl, 'a' - 10
    jmp .d2
.h1A:
    sub dl, 'A' - 10
    jmp .d2
.h1:
    sub dl, '0'
.d2:
    shl dl, 4
    mov dh, al
    cmp dh, '9'
    jbe .h2
    cmp dh, 'F'
    jbe .h2A
    sub dh, 'a' - 10
    jmp .d3
.h2A:
    sub dh, 'A' - 10
    jmp .d3
.h2:
    sub dh, '0'
.d3:
    or dl, dh
    pop rax
    ret

emit_load_syscall_arg:
    push rbx
    cmp al, 0
    je .elsa_imm
    cmp al, 1
    je .elsa_reg
    cmp al, 2
    je .elsa_var
    cmp al, 3
    je .elsa_lea
    pop rbx
    ret

.elsa_imm:
    mov al, 0x48
    cmp r8b, 8
    jb .e_imm_no_rex
    or al, 0x01
.e_imm_no_rex:
    mov byte [r13], al
    inc r13
    mov al, 0xB8
    mov bl, r8b
    and bl, 0x07
    add al, bl
    mov byte [r13], al
    inc r13
    mov qword [r13], rdx
    add r13, 8
    pop rbx
    ret

.elsa_reg:
    mov al, 0x48
    cmp dl, 8
    jb .e_reg_chk_dst
    or al, 0x04
.e_reg_chk_dst:
    cmp r8b, 8
    jb .e_reg_emit_rex
    or al, 0x01
.e_reg_emit_rex:
    mov byte [r13], al
    inc r13
    mov byte [r13], 0x89
    inc r13
    mov al, 0xC0
    mov bl, dl
    and bl, 0x07
    shl bl, 3
    or al, bl
    mov bl, r8b
    and bl, 0x07
    or al, bl
    mov byte [r13], al
    inc r13
    pop rbx
    ret

.elsa_var:
    mov al, 0x48
    cmp r8b, 8
    jb .e_var_no_rex
    or al, 0x04
.e_var_no_rex:
    mov byte [r13], al
    inc r13
    mov byte [r13], 0x8B
    inc r13
    mov al, 0x85
    mov bl, r8b
    and bl, 0x07
    shl bl, 3
    or al, bl
    mov byte [r13], al
    inc r13
    neg rdx
    mov dword [r13], edx
    add r13, 4
    pop rbx
    ret

.elsa_lea:
    mov al, 0x48
    cmp r8b, 8
    jb .e_lea_no_rex
    or al, 0x04
.e_lea_no_rex:
    mov byte [r13], al
    inc r13
    mov byte [r13], 0x8D
    inc r13
    mov al, 0x85
    mov bl, r8b
    and bl, 0x07
    shl bl, 3
    or al, bl
    mov byte [r13], al
    inc r13
    neg rdx
    mov dword [r13], edx
    add r13, 4
    pop rbx
    ret

emit_static_string:
    mov byte [r13], 0xEB
    inc r13
    mov byte [r13], dl
    inc r13

    push rsi
    push rdi
    push rcx
    mov rdi, r13
    mov ecx, edx
    rep movsb
    mov r13, rdi
    pop rcx
    pop rdi
    pop rsi

    mov byte [r13], 0x48
    inc r13
    mov byte [r13], 0x8D
    inc r13
    mov byte [r13], 0x35
    inc r13
    mov eax, edx
    neg eax
    sub eax, 7
    mov dword [r13], eax
    add r13, 4

    mov byte [r13], 0xB8
    inc r13
    mov dword [r13], 1
    add r13, 4

    mov byte [r13], 0xBF
    inc r13
    mov dword [r13], 1
    add r13, 4

    mov byte [r13], 0xBA
    inc r13
    mov dword [r13], edx
    add r13, 4

    mov word [r13], 0x050F
    add r13, 2
    ret

get_color_escape_info:
    mov rsi, qword [r12 + AstNode.value]
    mov eax, dword [r12 + AstNode.len]
    test eax, eax
    jz .col_def

    mov dl, byte [rsi]
    cmp dl, 'r'
    je .chk_r
    cmp dl, 'g'
    je .col_green
    cmp dl, 'y'
    je .col_yellow
    cmp dl, 'b'
    je .col_blue
    cmp dl, 'm'
    je .col_magenta
    cmp dl, 'c'
    je .col_cyan
    cmp dl, 'w'
    je .col_white
    jmp .col_def

.chk_r:
    cmp eax, 3
    je .col_red
    jmp .col_def

.col_red:
    mov rsi, .str_col_red
    mov edx, 5
    ret
.col_green:
    mov rsi, .str_col_green
    mov edx, 5
    ret
.col_yellow:
    mov rsi, .str_col_yellow
    mov edx, 5
    ret
.col_blue:
    mov rsi, .str_col_blue
    mov edx, 5
    ret
.col_magenta:
    mov rsi, .str_col_magenta
    mov edx, 5
    ret
.col_cyan:
    mov rsi, .str_col_cyan
    mov edx, 5
    ret
.col_white:
    mov rsi, .str_col_white
    mov edx, 5
    ret
.col_def:
    mov rsi, .str_col_reset
    mov edx, 4
    ret

.str_col_red:     db 1Bh, "[31m"
.str_col_green:   db 1Bh, "[32m"
.str_col_yellow:  db 1Bh, "[33m"
.str_col_blue:    db 1Bh, "[34m"
.str_col_magenta: db 1Bh, "[35m"
.str_col_cyan:    db 1Bh, "[36m"
.str_col_white:   db 1Bh, "[37m"
.str_col_reset:   db 1Bh, "[0m"

str_cls_seq:      db 1Bh, "[2J", 1Bh, "[H"
str_beep_seq:     db 07h
str_hide_cur_seq: db 1Bh, "[?25l"
str_show_cur_seq: db 1Bh, "[?25h"

sleep_code_template:
    xor edx, edx
    mov ecx, 1000
    div rcx
    imul rdx, rdx, 1000000
    push rdx                  
    push rax                  
    mov rdi, rsp
    xor esi, esi
    mov eax, 35               
    syscall
    add rsp, 16
sleep_code_template_end:
SLEEP_CODE_SIZE = sleep_code_template_end - sleep_code_template

say_num_code_template:
    sub rsp, 32
    lea rsi, [rsp + 31]
    mov byte [rsi], 0x0A       
    mov ecx, 1
    mov r10, 10
    xor r8d, r8d

    test rax, rax
    jns .sn_not_neg
    neg rax
    mov r8b, 1
.sn_not_neg:
    test rax, rax
    jnz .sn_loop
    dec rsi
    mov byte [rsi], '0'
    inc ecx
    jmp .sn_check_sign

.sn_loop:
    test rax, rax
    jz .sn_check_sign
    xor edx, edx
    div r10
    add dl, '0'
    dec rsi
    mov byte [rsi], dl
    inc ecx
    jmp .sn_loop

.sn_check_sign:
    test r8b, r8b
    jz .sn_write
    dec rsi
    mov byte [rsi], '-'
    inc ecx

.sn_write:
    mov edx, ecx
    mov edi, 1
    mov eax, 1               
    syscall
    add rsp, 32
say_num_code_template_end:
SAY_NUM_CODE_SIZE = say_num_code_template_end - say_num_code_template

locate_code_template:
    push rax                  
    sub rsp, 32
    lea rsi, [rsp + 31]
    mov byte [rsi], 'H'
    mov r10, 10

    mov rax, r8
    test rax, rax
    jnz .loc_x_loop
    dec rsi
    mov byte [rsi], '0'
    jmp .loc_x_done
.loc_x_loop:
    test rax, rax
    jz .loc_x_done
    xor edx, edx
    div r10
    add dl, '0'
    dec rsi
    mov byte [rsi], dl
    jmp .loc_x_loop
.loc_x_done:

    dec rsi
    mov byte [rsi], ';'

    mov rax, r9
    test rax, rax
    jnz .loc_y_loop
    dec rsi
    mov byte [rsi], '0'
    jmp .loc_y_done
.loc_y_loop:
    test rax, rax
    jz .loc_y_done
    xor edx, edx
    div r10
    add dl, '0'
    dec rsi
    mov byte [rsi], dl
    jmp .loc_y_loop
.loc_y_done:

    dec rsi
    mov byte [rsi], '['
    dec rsi
    mov byte [rsi], 1Bh

    mov rdx, rsp
    add rdx, 32
    sub rdx, rsi
    mov edi, 1
    mov eax, 1                
    syscall
    add rsp, 32
    pop rax                   
locate_code_template_end:
LOCATE_CODE_SIZE = locate_code_template_end - locate_code_template

generate_code:
    push rbp
    mov rbp, rsp
    mov r12, rsi
    mov r13, rdi
    mov [code_start_ptr], rdi
    mov qword [labels_count], 0

    push r12
    push r13
    push rcx
    xor r14, r14

.pass1_loop:
    cmp rcx, 0
    je .pass1_done

    mov eax, dword [r12 + AstNode.type]

    cmp eax, AST_NODE_LABEL
    je .p1_label
    cmp eax, AST_NODE_SUB
    je .p1_prologue
    cmp eax, AST_NODE_FUNC
    je .p1_prologue
    cmp eax, AST_NODE_ASSIGN_IMM
    je .p1_assign_imm
    cmp eax, AST_NODE_ASSIGN_REG
    je .p1_assign_reg
    cmp eax, AST_NODE_BINOP_REG
    je .p1_binop_reg
    cmp eax, AST_NODE_BINOP_IMM
    je .p1_binop_imm
    cmp eax, AST_NODE_LOAD_MEM
    je .p1_load_mem
    cmp eax, AST_NODE_STORE_MEM
    je .p1_store_mem
    cmp eax, AST_NODE_STORE_REG
    je .p1_store_reg
    cmp eax, AST_NODE_SIMD_LOAD
    je .p1_simd_load
    cmp eax, AST_NODE_SIMD_STORE
    je .p1_simd_store
    cmp eax, AST_NODE_SIMD_BINOP
    je .p1_simd_binop
    cmp eax, AST_NODE_SYSCALL
    je .p1_syscall
    cmp eax, AST_NODE_CMP_REG
    je .p1_cmp_reg
    cmp eax, AST_NODE_CMP_IMM
    je .p1_cmp_imm
    cmp eax, AST_NODE_JMP
    je .p1_jmp
    cmp eax, AST_NODE_CALL
    je .p1_call
    cmp eax, AST_NODE_JNE
    je .p1_jcc
    cmp eax, AST_NODE_JE
    je .p1_jcc
    cmp eax, AST_NODE_JB
    je .p1_jcc
    cmp eax, AST_NODE_JAE
    je .p1_jcc
    cmp eax, AST_NODE_JL
    je .p1_jcc
    cmp eax, AST_NODE_JLE
    je .p1_jcc
    cmp eax, AST_NODE_JG
    je .p1_jcc
    cmp eax, AST_NODE_JGE
    je .p1_jcc
    cmp eax, AST_NODE_JA
    je .p1_jcc
    cmp eax, AST_NODE_JBE
    je .p1_jcc
    cmp eax, AST_NODE_PRINT_STR
    je .p1_print_str
    cmp eax, AST_NODE_CLI
    je .p1_single_byte
    cmp eax, AST_NODE_STI
    je .p1_single_byte
    cmp eax, AST_NODE_HLT
    je .p1_single_byte

    cmp eax, AST_NODE_OUTB
    je .p1_outb
    cmp eax, AST_NODE_OUTW
    je .p1_outw
    cmp eax, AST_NODE_OUTD
    je .p1_outd
    cmp eax, AST_NODE_INB
    je .p1_inb
    cmp eax, AST_NODE_INW
    je .p1_inw
    cmp eax, AST_NODE_IND
    je .p1_ind
    cmp eax, AST_NODE_MOV_TO_CR
    je .p1_mov_cr
    cmp eax, AST_NODE_MOV_FROM_CR
    je .p1_mov_cr
    cmp eax, AST_NODE_LIDT
    je .p1_dt
    cmp eax, AST_NODE_LGDT
    je .p1_dt

    cmp eax, AST_NODE_LOGIC_NOT
    je .p1_logic_not
    cmp eax, AST_NODE_LOGIC_AND
    je .p1_logic_and
    cmp eax, AST_NODE_LOGIC_OR
    je .p1_logic_or
    cmp eax, AST_NODE_PAREN_EXPR
    je .p1_paren_expr
    cmp eax, AST_NODE_ENABLE_GC
    je .p1_enable_gc
    cmp eax, AST_NODE_GC_NEW
    je .p1_gc_new
    cmp eax, AST_NODE_SAY
    je .p1_say
    cmp eax, AST_NODE_REPEAT
    je .p1_repeat
    cmp eax, AST_NODE_REPEAT_END
    je .p1_repeat_end
    cmp eax, AST_NODE_ENABLE_BLOCKS
    je .p1_skip
    cmp eax, AST_NODE_INLINE_ASM
    je .p1_inline_asm
    cmp eax, AST_NODE_INLINE_HEX
    je .p1_inline_hex
    cmp eax, AST_NODE_INLINE_C
    je .p1_inline_c
    cmp eax, AST_NODE_PUSH
    je .p1_single_byte
    cmp eax, AST_NODE_POP
    je .p1_single_byte
    
    cmp eax, AST_NODE_NET_LISTEN
    je .p1_net_listen
    cmp eax, AST_NODE_NET_ACCEPT
    je .p1_net_accept
    cmp eax, AST_NODE_NET_SEND
    je .p1_sys_3args_gen
    cmp eax, AST_NODE_NET_RECV
    je .p1_sys_3args_gen
    cmp eax, AST_NODE_NET_SENDFILE
    je .p1_sys_sendfile
    cmp eax, AST_NODE_NET_CLOSE
    je .p1_sys_1arg_gen
    cmp eax, AST_NODE_SYS_WRITE
    je .p1_sys_3args_gen
    cmp eax, AST_NODE_SYS_READ
    je .p1_sys_3args_gen
    cmp eax, AST_NODE_SYS_SOCKET
    je .p1_sys_3args_gen
    cmp eax, AST_NODE_SYS_BIND
    je .p1_sys_3args_gen
    cmp eax, AST_NODE_SYS_ACCEPT
    je .p1_sys_3args_gen
    cmp eax, AST_NODE_SYS_OPEN
    je .p1_sys_3args_gen
    cmp eax, AST_NODE_SYS_SENDFILE
    je .p1_sys_sendfile
    cmp eax, AST_NODE_SYS_LISTEN
    je .p1_sys_2args_gen
    cmp eax, AST_NODE_SYS_CLOSE
    je .p1_sys_1arg_gen
    cmp eax, AST_NODE_SYS_EXIT
    je .p1_sys_exit
    
    cmp eax, AST_NODE_KIDS_CLS
    je .p1_kids_cls
    cmp eax, AST_NODE_KIDS_BEEP
    je .p1_kids_beep
    cmp eax, AST_NODE_KIDS_SLEEP
    je .p1_kids_sleep
    cmp eax, AST_NODE_KIDS_SAY_NUM
    je .p1_kids_say_num
    cmp eax, AST_NODE_KIDS_LOCATE
    je .p1_kids_locate
    cmp eax, AST_NODE_KIDS_COLOR
    je .p1_kids_color
    cmp eax, AST_NODE_KIDS_HIDE_CURSOR
    je .p1_kids_hide_cur
    cmp eax, AST_NODE_KIDS_SHOW_CURSOR
    je .p1_kids_show_cur

    cmp eax, AST_NODE_VAR_ASSIGN_IMM
    je .p1_var_imm
    cmp eax, AST_NODE_VAR_ASSIGN_REG
    je .p1_var_reg
    cmp eax, AST_NODE_REG_ASSIGN_VAR
    je .p1_reg_var
    cmp eax, 60
    je .p1_lea_var
    cmp eax, AST_NODE_RETURN
    je .p1_return
    jmp .p1_next

.p1_kids_cls:
    add r14, 33
    jmp .p1_next
.p1_kids_beep:
    add r14, 27
    jmp .p1_next
.p1_kids_hide_cur:
    add r14, 32
    jmp .p1_next
.p1_kids_show_cur:
    add r14, 32
    jmp .p1_next
.p1_kids_color:
    call get_color_escape_info
    add r14, 26
    add r14, rdx
    jmp .p1_next
.p1_kids_sleep:
    mov edx, dword [r12 + AstNode.len]
    call .add_sys_arg_size
    add r14, SLEEP_CODE_SIZE
    jmp .p1_next
.p1_kids_say_num:
    mov edx, dword [r12 + AstNode.len]
    call .add_sys_arg_size
    add r14, SAY_NUM_CODE_SIZE
    jmp .p1_next
.p1_kids_locate:
    mov edx, dword [r12 + AstNode.len]
    call .add_sys_arg_size
    shr edx, 8
    call .add_sys_arg_size
    add r14, LOCATE_CODE_SIZE
    jmp .p1_next

.p1_label:
    mov rbx, [labels_count]
    shl rbx, 4
    mov r8, qword [r12 + AstNode.value]
    mov [labels_table + rbx], r8
    mov [labels_table + rbx + 8], r14
    inc qword [labels_count]
    jmp .p1_next

.p1_prologue:
    mov rbx, [labels_count]
    shl rbx, 4
    mov r8, qword [r12 + AstNode.value]
    mov [labels_table + rbx], r8
    mov [labels_table + rbx + 8], r14
    inc qword [labels_count]
    add r14, 11
    jmp .p1_next

.p1_assign_imm:
    add r14, 10
    jmp .p1_next
.p1_assign_reg:
    add r14, 3
    jmp .p1_next
.p1_binop_reg:
    mov edx, dword [r12 + AstNode.len]
    cmp edx, OP_MUL
    je .p1_binop_mul
    add r14, 3
    jmp .p1_next
.p1_binop_mul:
    add r14, 4
    jmp .p1_next
.p1_binop_imm:
    mov edx, dword [r12 + AstNode.len]
    cmp edx, OP_SHR
    je .p1_bi_shift
    cmp edx, OP_SHL
    je .p1_bi_shift
    add r14, 7
    jmp .p1_next
.p1_bi_shift:
    add r14, 4
    jmp .p1_next
.p1_load_mem:
    mov r8, qword [r12 + AstNode.right]
    mov r9, qword [r12 + AstNode.value]
    call get_addr_len_disp
    mov edx, dword [r12 + AstNode.len]
    cmp edx, 4
    je .p1_lm_dw
    add r14, 2
    add r14, rax
    jmp .p1_next
.p1_lm_dw:
    add r14, 1
    add r14, rax
    jmp .p1_next
.p1_store_mem:
    mov r8, qword [r12 + AstNode.left]
    mov r9, qword [r12 + AstNode.right]
    call get_addr_len_disp
    mov edx, dword [r12 + AstNode.len]
    cmp edx, 1
    je .p1_sm1
    cmp edx, 2
    je .p1_sm2
    cmp edx, 4
    je .p1_sm4
    add r14, 6
    add r14, rax
    jmp .p1_next
.p1_sm1:
    add r14, 2
    add r14, rax
    jmp .p1_next
.p1_sm2:
    add r14, 4
    add r14, rax
    jmp .p1_next
.p1_sm4:
    add r14, 5
    add r14, rax
    jmp .p1_next
.p1_store_reg:
    mov r8, qword [r12 + AstNode.left]
    mov r9, qword [r12 + AstNode.value]
    call get_addr_len_disp
    mov edx, dword [r12 + AstNode.len]
    cmp edx, 1
    je .p1_sr_single
    cmp edx, 4
    je .p1_sr_single
    add r14, 2
    add r14, rax
    jmp .p1_next
.p1_sr_single:
    add r14, 1
    add r14, rax
    jmp .p1_next
.p1_simd_load:
    mov r8, qword [r12 + AstNode.right]
    mov r9, qword [r12 + AstNode.value]
    call get_addr_len_disp
    add r14, 2
    add r14, rax
    jmp .p1_next
.p1_simd_store:
    mov r8, qword [r12 + AstNode.left]
    mov r9, qword [r12 + AstNode.value]
    call get_addr_len_disp
    add r14, 2
    add r14, rax
    jmp .p1_next
.p1_simd_binop:
    add r14, 3
    jmp .p1_next
.p1_syscall:
    add r14, 2
    jmp .p1_next
.p1_cmp_reg:
    add r14, 3
    jmp .p1_next
.p1_cmp_imm:
    add r14, 7
    jmp .p1_next
.p1_jmp:
    add r14, 5
    jmp .p1_next
.p1_call:
    add r14, 5
    jmp .p1_next
.p1_jcc:
    add r14, 6
    jmp .p1_next
.p1_print_str:
    mov eax, dword [r12 + AstNode.len]
    add r14, 26
    add r14, rax
    jmp .p1_next
.p1_single_byte:
    add r14, 1
    jmp .p1_next

.p1_outb:
    mov edx, dword [r12 + AstNode.len]
    test edx, edx
    jz .p1_ob_lit
    add r14, 1                
    jmp .p1_next
.p1_ob_lit:
    add r14, 7                
    jmp .p1_next

.p1_outw:
    mov edx, dword [r12 + AstNode.len]
    test edx, edx
    jz .p1_ow_lit
    add r14, 2               
    jmp .p1_next
.p1_ow_lit:
    add r14, 8
    jmp .p1_next

.p1_outd:
    mov edx, dword [r12 + AstNode.len]
    test edx, edx
    jz .p1_od_lit
    add r14, 1               
    jmp .p1_next
.p1_od_lit:
    add r14, 8
    jmp .p1_next

.p1_inb:
    mov edx, dword [r12 + AstNode.len]
    test edx, edx
    jz .p1_ib_lit
    add r14, 5                 
    jmp .p1_next
.p1_ib_lit:
    add r14, 9
    jmp .p1_next

.p1_inw:
    mov edx, dword [r12 + AstNode.len]
    test edx, edx
    jz .p1_iw_lit
    add r14, 6               
    jmp .p1_next
.p1_iw_lit:
    add r14, 10
    jmp .p1_next

.p1_ind:
    mov edx, dword [r12 + AstNode.len]
    test edx, edx
    jz .p1_id_lit
    add r14, 4               
    jmp .p1_next
.p1_id_lit:
    add r14, 8
    jmp .p1_next

.p1_mov_cr:
    add r14, 3               
    jmp .p1_next

.p1_dt:
    add r14, 7             
    jmp .p1_next

.p1_logic_not:
    add r14, 10
    jmp .p1_next
.p1_logic_and:
    add r14, 21
    jmp .p1_next
.p1_logic_or:
    add r14, 13
    jmp .p1_next
.p1_paren_expr:
    mov edx, dword [r12 + AstNode.len]
    cmp edx, OP_MUL
    je .p1_pe_mul
    add r14, 6
    jmp .p1_next
.p1_pe_mul:
    add r14, 7
    jmp .p1_next
.p1_enable_gc:
    add r14, 20
    jmp .p1_next
.p1_gc_new:
    mov rax, qword [r12 + AstNode.left]
    test rax, rax
    jz .p1_gn_rax
    add r14, 36
    jmp .p1_next
.p1_gn_rax:
    add r14, 33
    jmp .p1_next
.p1_say:
    mov eax, dword [r12 + AstNode.len]
    add r14, 27
    add r14, rax
    jmp .p1_next
.p1_repeat:
    mov qword [r12 + AstNode.left], r14
    add r14, 11
    jmp .p1_next
.p1_repeat_end:
    mov r8, qword [r12 + AstNode.left]
    mov rax, qword [r8 + AstNode.left]
    mov qword [r12 + AstNode.value], rax
    add r14, 20
    jmp .p1_next
.p1_skip:
    jmp .p1_next

.p1_inline_hex:
    push rsi
    push rcx
    mov rsi, qword [r12 + AstNode.left]
    mov ecx, dword [r12 + AstNode.right]
    xor r8, r8
.p1_hex_loop:
    test ecx, ecx
    jz .p1_hex_done
    lodsb
    dec ecx
    cmp al, '#'
    je .p1_hex_comment
    call is_hex_char
    test ah, ah
    jz .p1_hex_loop
.p1_wait_h2:
    test ecx, ecx
    jz .p1_hex_done
    lodsb
    dec ecx
    cmp al, '#'
    je .p1_hex_comment2
    call is_hex_char
    test ah, ah
    jz .p1_wait_h2
    inc r8
    jmp .p1_hex_loop

.p1_hex_comment:
    test ecx, ecx
    jz .p1_hex_done
    lodsb
    dec ecx
    cmp al, 0x0A
    je .p1_hex_loop
    jmp .p1_hex_comment

.p1_hex_comment2:
    test ecx, ecx
    jz .p1_hex_done
    lodsb
    dec ecx
    cmp al, 0x0A
    je .wait_second
    jmp .p1_hex_comment2

.p1_hex_done:
    add r14, r8
    pop rcx
    pop rsi
    jmp .p1_next

.p1_inline_asm:
    add r14, 50
    jmp .p1_next
.p1_inline_c:
    add r14, 50
    jmp .p1_next

.p1_net_listen:
    mov edx, dword [r12 + AstNode.len]
    call .add_sys_arg_size
    add r14, NET_LISTEN_SIZE
    jmp .p1_next

.p1_net_accept:
    mov edx, dword [r12 + AstNode.len]
    call .add_sys_arg_size
    add r14, 11
    jmp .p1_next

.p1_sys_3args_gen:
    mov edx, dword [r12 + AstNode.len]
    call .add_sys_arg_size
    shr edx, 8
    call .add_sys_arg_size
    shr edx, 8
    call .add_sys_arg_size
    add r14, 7
    jmp .p1_next

.p1_sys_sendfile:
    mov edx, dword [r12 + AstNode.len]
    call .add_sys_arg_size
    shr edx, 8
    call .add_sys_arg_size
    shr edx, 8
    call .add_sys_arg_size
    add r14, 9
    jmp .p1_next

.p1_sys_2args_gen:
    mov edx, dword [r12 + AstNode.len]
    call .add_sys_arg_size
    shr edx, 8
    call .add_sys_arg_size
    add r14, 7
    jmp .p1_next

.p1_sys_1arg_gen:
    mov edx, dword [r12 + AstNode.len]
    call .add_sys_arg_size
    add r14, 7
    jmp .p1_next

.add_sys_arg_size:
    mov al, dl
    and al, 0xFF
    cmp al, 0
    je .sas_imm
    cmp al, 1
    je .sas_reg
    add r14, 7
    ret
.sas_imm:
    add r14, 10
    ret
.sas_reg:
    add r14, 3
    ret

.p1_sys_exit:
    mov rax, qword [r12 + AstNode.left]
    test rax, rax
    jnz .p1_se_reg
    add r14, 12
    jmp .p1_next
.p1_se_reg:
    add r14, 10
    jmp .p1_next
.p1_var_imm:
    mov edx, dword [r12 + AstNode.len]
    cmp edx, 1
    je .p1_vi1
    cmp edx, 2
    je .p1_vi2
    cmp edx, 4
    je .p1_vi4
    add r14, 11
    jmp .p1_next
.p1_vi1:
    add r14, 7
    jmp .p1_next
.p1_vi2:
    add r14, 9
    jmp .p1_next
.p1_vi4:
    add r14, 10
    jmp .p1_next
.p1_var_reg:
    mov edx, dword [r12 + AstNode.len]
    cmp edx, 1
    je .p1_vr1
    cmp edx, 2
    je .p1_vr2
    cmp edx, 4
    je .p1_vr4
    add r14, 7
    jmp .p1_next
.p1_vr1:
    add r14, 6
    jmp .p1_next
.p1_vr2:
    add r14, 7
    jmp .p1_next
.p1_vr4:
    add r14, 6
    jmp .p1_next
.p1_reg_var:
    mov edx, dword [r12 + AstNode.len]
    cmp edx, 1
    je .p1_rv1
    cmp edx, 2
    je .p1_rv2
    cmp edx, 4
    je .p1_rv4
    add r14, 7
    jmp .p1_next
.p1_rv1:
    add r14, 8
    jmp .p1_next
.p1_rv2:
    add r14, 7
    jmp .p1_next
.p1_rv4:
    add r14, 6
    jmp .p1_next
.p1_lea_var:
    add r14, 7
    jmp .p1_next
.p1_return:
    add r14, 9
    jmp .p1_next
.p1_next:
    add r12, 32
    dec rcx
    jmp .pass1_loop
.pass1_done:
    pop rcx
    pop r13
    pop r12

.cg_loop:
    cmp rcx, 0
    je .cg_done

    mov eax, dword [r12 + AstNode.type]

    cmp eax, AST_NODE_SUB
    je .emit_prologue
    cmp eax, AST_NODE_FUNC
    je .emit_prologue
    cmp eax, AST_NODE_ASSIGN_IMM
    je .emit_assign_imm
    cmp eax, AST_NODE_ASSIGN_REG
    je .emit_assign_reg
    cmp eax, AST_NODE_BINOP_REG
    je .emit_binop_reg
    cmp eax, AST_NODE_BINOP_IMM
    je .emit_binop_imm
    cmp eax, AST_NODE_LOAD_MEM
    je .emit_load_mem
    cmp eax, AST_NODE_STORE_MEM
    je .emit_store_mem
    cmp eax, AST_NODE_STORE_REG
    je .emit_store_reg
    cmp eax, AST_NODE_SIMD_LOAD
    je .emit_simd_load
    cmp eax, AST_NODE_SIMD_STORE
    je .emit_simd_store
    cmp eax, AST_NODE_SIMD_BINOP
    je .emit_simd_binop
    cmp eax, AST_NODE_SYSCALL
    je .emit_syscall
    cmp eax, AST_NODE_CMP_REG
    je .emit_cmp_reg
    cmp eax, AST_NODE_CMP_IMM
    je .emit_cmp_imm
    cmp eax, AST_NODE_JMP
    je .emit_jmp
    cmp eax, AST_NODE_CALL
    je .emit_call
    cmp eax, AST_NODE_JNE
    je .emit_jne
    cmp eax, AST_NODE_JE
    je .emit_je
    cmp eax, AST_NODE_JB
    je .emit_jb
    cmp eax, AST_NODE_JAE
    je .emit_jae
    cmp eax, AST_NODE_JL
    je .emit_jl
    cmp eax, AST_NODE_JLE
    je .emit_jle
    cmp eax, AST_NODE_JG
    je .emit_jg
    cmp eax, AST_NODE_JGE
    je .emit_jge
    cmp eax, AST_NODE_JA
    je .emit_ja
    cmp eax, AST_NODE_JBE
    je .emit_jbe
    cmp eax, AST_NODE_PRINT_STR
    je .emit_print_str
    cmp eax, AST_NODE_CLI
    je .emit_cli
    cmp eax, AST_NODE_STI
    je .emit_sti
    cmp eax, AST_NODE_HLT
    je .emit_hlt

    ; mode "osdev"
    cmp eax, AST_NODE_OUTB
    je .emit_outb
    cmp eax, AST_NODE_OUTW
    je .emit_outw
    cmp eax, AST_NODE_OUTD
    je .emit_outd
    cmp eax, AST_NODE_INB
    je .emit_inb
    cmp eax, AST_NODE_INW
    je .emit_inw
    cmp eax, AST_NODE_IND
    je .emit_ind
    cmp eax, AST_NODE_MOV_TO_CR
    je .emit_mov_to_cr
    cmp eax, AST_NODE_MOV_FROM_CR
    je .emit_mov_from_cr
    cmp eax, AST_NODE_LIDT
    je .emit_lidt
    cmp eax, AST_NODE_LGDT
    je .emit_lgdt

    cmp eax, AST_NODE_LOGIC_NOT
    je .emit_logic_not
    cmp eax, AST_NODE_LOGIC_AND
    je .emit_logic_and
    cmp eax, AST_NODE_LOGIC_OR
    je .emit_logic_or
    cmp eax, AST_NODE_PAREN_EXPR
    je .emit_paren_expr
    cmp eax, AST_NODE_ENABLE_GC
    je .emit_enable_gc
    cmp eax, AST_NODE_GC_NEW
    je .emit_gc_new
    cmp eax, AST_NODE_SAY
    je .emit_say
    cmp eax, AST_NODE_REPEAT
    je .emit_repeat
    cmp eax, AST_NODE_REPEAT_END
    je .emit_repeat_end
    cmp eax, AST_NODE_ENABLE_BLOCKS
    je .cg_next
    cmp eax, AST_NODE_INLINE_ASM
    je .emit_inline_asm
    cmp eax, AST_NODE_INLINE_HEX
    je .emit_inline_hex
    cmp eax, AST_NODE_INLINE_C
    je .emit_inline_c
    cmp eax, AST_NODE_PUSH
    je .emit_push
    cmp eax, AST_NODE_POP
    je .emit_pop

    ; mode "sys"
    ; mode "net"
    cmp eax, AST_NODE_NET_LISTEN
    je .emit_net_listen
    cmp eax, AST_NODE_NET_ACCEPT
    je .emit_net_accept
    cmp eax, AST_NODE_NET_SEND
    je .emit_sys_write
    cmp eax, AST_NODE_NET_RECV
    je .emit_sys_read
    cmp eax, AST_NODE_NET_SENDFILE
    je .emit_sys_sendfile
    cmp eax, AST_NODE_NET_CLOSE
    je .emit_sys_close
    cmp eax, AST_NODE_SYS_WRITE
    je .emit_sys_write
    cmp eax, AST_NODE_SYS_READ
    je .emit_sys_read
    cmp eax, AST_NODE_SYS_SOCKET
    je .emit_sys_socket
    cmp eax, AST_NODE_SYS_BIND
    je .emit_sys_bind
    cmp eax, AST_NODE_SYS_LISTEN
    je .emit_sys_listen
    cmp eax, AST_NODE_SYS_ACCEPT
    je .emit_sys_accept
    cmp eax, AST_NODE_SYS_CLOSE
    je .emit_sys_close
    cmp eax, AST_NODE_SYS_OPEN
    je .emit_sys_open
    cmp eax, AST_NODE_SYS_SENDFILE
    je .emit_sys_sendfile
    cmp eax, AST_NODE_SYS_EXIT
    je .emit_sys_exit

    ; mode "kids"
    cmp eax, AST_NODE_KIDS_CLS
    je .emit_kids_cls
    cmp eax, AST_NODE_KIDS_BEEP
    je .emit_kids_beep
    cmp eax, AST_NODE_KIDS_SLEEP
    je .emit_kids_sleep
    cmp eax, AST_NODE_KIDS_SAY_NUM
    je .emit_kids_say_num
    cmp eax, AST_NODE_KIDS_LOCATE
    je .emit_kids_locate
    cmp eax, AST_NODE_KIDS_COLOR
    je .emit_kids_color
    cmp eax, AST_NODE_KIDS_HIDE_CURSOR
    je .emit_kids_hide_cur
    cmp eax, AST_NODE_KIDS_SHOW_CURSOR
    je .emit_kids_show_cur

    cmp eax, AST_NODE_VAR_ASSIGN_IMM
    je .emit_var_imm
    cmp eax, AST_NODE_VAR_ASSIGN_REG
    je .emit_var_reg
    cmp eax, AST_NODE_REG_ASSIGN_VAR
    je .emit_reg_var
    cmp eax, 60
    je .emit_lea_var
    cmp eax, AST_NODE_RETURN
    je .emit_epilogue
    jmp .cg_next

.emit_kids_cls:
    mov rsi, str_cls_seq
    mov edx, 7
    call emit_static_string
    jmp .cg_next

.emit_kids_beep:
    mov rsi, str_beep_seq
    mov edx, 1
    call emit_static_string
    jmp .cg_next

.emit_kids_hide_cur:
    mov rsi, str_hide_cur_seq
    mov edx, 6
    call emit_static_string
    jmp .cg_next

.emit_kids_show_cur:
    mov rsi, str_show_cur_seq
    mov edx, 6
    call emit_static_string
    jmp .cg_next

.emit_kids_color:
    call get_color_escape_info
    call emit_static_string
    jmp .cg_next

.emit_kids_sleep:
    mov al, byte [r12 + AstNode.len]
    mov rdx, qword [r12 + AstNode.value]
    mov r8b, 0                
    call emit_load_syscall_arg

    push rdi
    mov rdi, r13
    push rsi
    push rcx
    mov rsi, sleep_code_template
    mov ecx, SLEEP_CODE_SIZE
    rep movsb
    pop rcx
    pop rsi
    mov r13, rdi
    pop rdi
    jmp .cg_next

.emit_kids_say_num:
    mov al, byte [r12 + AstNode.len]
    mov rdx, qword [r12 + AstNode.value]
    mov r8b, 0                
    call emit_load_syscall_arg

    push rdi
    mov rdi, r13
    push rsi
    push rcx
    mov rsi, say_num_code_template
    mov ecx, SAY_NUM_CODE_SIZE
    rep movsb
    pop rcx
    pop rsi
    mov r13, rdi
    pop rdi
    jmp .cg_next

.emit_kids_locate:
    mov al, byte [r12 + AstNode.len]
    mov rdx, qword [r12 + AstNode.left]
    mov r8b, 8
    call emit_load_syscall_arg

    mov al, byte [r12 + AstNode.len + 1]
    mov rdx, qword [r12 + AstNode.right]
    mov r8b, 9
    call emit_load_syscall_arg

    push rdi
    mov rdi, r13
    push rsi
    push rcx
    mov rsi, locate_code_template
    mov ecx, LOCATE_CODE_SIZE
    rep movsb
    pop rcx
    pop rsi
    mov r13, rdi
    pop rdi
    jmp .cg_next

.emit_push:
    mov al, 0x50
    add al, byte [r12 + AstNode.value]
    mov byte [r13], al
    inc r13
    jmp .cg_next

.emit_pop:
    mov al, 0x58
    add al, byte [r12 + AstNode.value]
    mov byte [r13], al
    inc r13
    jmp .cg_next

.emit_prologue:
    mov byte [r13], 0x55
    inc r13
    mov word [r13], 0x8948
    add r13, 2
    mov byte [r13], 0xE5
    inc r13
    mov word [r13], 0x8148
    add r13, 2
    mov byte [r13], 0xEC
    inc r13
    mov dword [r13], 4096
    add r13, 4
    jmp .cg_next

.emit_assign_imm:
    mov al, 0x48
    mov dl, byte [r12 + AstNode.len]
    cmp dl, 8
    jb .eai_no_rex_b
    or al, 0x01
.eai_no_rex_b:
    mov byte [r13], al
    inc r13
    mov al, 0xB8
    mov dl, byte [r12 + AstNode.len]
    and dl, 0x07
    add al, dl
    mov byte [r13], al
    inc r13
    mov rax, qword [r12 + AstNode.value]
    mov qword [r13], rax
    add r13, 8
    jmp .cg_next

.emit_assign_reg:
    mov al, 0x48
    mov dl, byte [r12 + AstNode.value]
    cmp dl, 8
    jb .ear_chk_dst
    or al, 0x04
.ear_chk_dst:
    mov dl, byte [r12 + AstNode.len]
    cmp dl, 8
    jb .ear_emit_rex
    or al, 0x01
.ear_emit_rex:
    mov byte [r13], al
    inc r13
    mov byte [r13], 0x89
    inc r13
    mov al, 0xC0
    mov dl, byte [r12 + AstNode.value]
    and dl, 0x07
    shl dl, 3
    or al, dl
    mov dl, byte [r12 + AstNode.len]
    and dl, 0x07
    or al, dl
    mov byte [r13], al
    inc r13
    jmp .cg_next

.emit_binop_reg:
    mov edx, dword [r12 + AstNode.len]
    cmp edx, OP_MUL
    je .emit_mul_r

    mov al, 0x48
    mov dl, byte [r12 + AstNode.right] 
    cmp dl, 8
    jb .ebr_chk_dst
    or al, 0x04          
.ebr_chk_dst:
    mov dl, byte [r12 + AstNode.left]  
    cmp dl, 8
    jb .ebr_emit_rex
    or al, 0x01          
.ebr_emit_rex:
    mov byte [r13], al
    inc r13

    mov edx, dword [r12 + AstNode.len]
    cmp edx, OP_ADD
    je .emit_add_r
    cmp edx, OP_SUB
    je .emit_sub_r
    cmp edx, OP_XOR
    je .emit_xor_r
    cmp edx, OP_AND
    je .emit_and_r
    jmp .cg_next

.emit_add_r:
    mov byte [r13], 0x01
    jmp .emit_modrm_r
.emit_sub_r:
    mov byte [r13], 0x29
    jmp .emit_modrm_r
.emit_xor_r:
    mov byte [r13], 0x31
    jmp .emit_modrm_r
.emit_and_r:
    mov byte [r13], 0x21
    jmp .emit_modrm_r

.emit_mul_r:
    mov al, 0x48
    mov dl, byte [r12 + AstNode.left] 
    cmp dl, 8
    jb .emr_chk_src
    or al, 0x04
.emr_chk_src:
    mov dl, byte [r12 + AstNode.right] 
    cmp dl, 8
    jb .emr_emit_rex
    or al, 0x01
.emr_emit_rex:
    mov byte [r13], al
    inc r13
    mov word [r13], 0xAF0F
    add r13, 2
    mov al, 0xC0
    mov dl, byte [r12 + AstNode.left]
    and dl, 0x07
    shl dl, 3
    or al, dl
    mov dl, byte [r12 + AstNode.right]
    and dl, 0x07
    or al, dl
    mov byte [r13], al
    inc r13
    jmp .cg_next

.emit_modrm_r:
    inc r13
    mov al, 0xC0
    mov dl, byte [r12 + AstNode.right]
    and dl, 0x07
    shl dl, 3
    or al, dl
    mov dl, byte [r12 + AstNode.left]
    and dl, 0x07
    or al, dl
    mov byte [r13], al
    inc r13
    jmp .cg_next

.emit_binop_imm:
    mov byte [r13], 0x48
    inc r13
    mov edx, dword [r12 + AstNode.len]
    mov al, byte [r12 + AstNode.left]

    cmp edx, OP_ADD
    je .modrm_add_imm
    cmp edx, OP_SUB
    je .modrm_sub_imm
    cmp edx, OP_AND
    je .modrm_and_imm
    cmp edx, OP_XOR
    je .modrm_xor_imm
    cmp edx, OP_MUL
    je .modrm_mul_imm
    cmp edx, OP_SHR
    je .modrm_shr_imm
    cmp edx, OP_SHL
    je .modrm_shl_imm
    jmp .cg_next

.modrm_add_imm:
    mov byte [r13], 0x81
    inc r13
    or al, 0xC0
    mov byte [r13], al
    inc r13
    mov rax, qword [r12 + AstNode.value]
    mov dword [r13], eax
    add r13, 4
    jmp .cg_next

.modrm_sub_imm:
    mov byte [r13], 0x81
    inc r13
    or al, 0xE8
    mov byte [r13], al
    inc r13
    mov rax, qword [r12 + AstNode.value]
    mov dword [r13], eax
    add r13, 4
    jmp .cg_next

.modrm_and_imm:
    mov byte [r13], 0x81
    inc r13
    or al, 0xE0
    mov byte [r13], al
    inc r13
    mov rax, qword [r12 + AstNode.value]
    mov dword [r13], eax
    add r13, 4
    jmp .cg_next

.modrm_xor_imm:
    mov byte [r13], 0x81
    inc r13
    or al, 0xF0
    mov byte [r13], al
    inc r13
    mov rax, qword [r12 + AstNode.value]
    mov dword [r13], eax
    add r13, 4
    jmp .cg_next

.modrm_mul_imm:
    mov byte [r13], 0x69
    inc r13
    mov dl, al
    shl dl, 3
    or al, dl
    or al, 0xC0
    mov byte [r13], al
    inc r13
    mov rax, qword [r12 + AstNode.value]
    mov dword [r13], eax
    add r13, 4
    jmp .cg_next

.modrm_shr_imm:
    mov byte [r13], 0xC1
    inc r13
    or al, 0xE8
    mov byte [r13], al
    inc r13
    mov rax, qword [r12 + AstNode.value]
    mov byte [r13], al
    inc r13
    jmp .cg_next

.modrm_shl_imm:
    mov byte [r13], 0xC1
    inc r13
    or al, 0xE0
    mov byte [r13], al
    inc r13
    mov rax, qword [r12 + AstNode.value]
    mov byte [r13], al
    inc r13
    jmp .cg_next

.emit_load_mem:
    mov edx, dword [r12 + AstNode.len]
    mov r8, qword [r12 + AstNode.right]
    mov r9, qword [r12 + AstNode.value]
    mov al, byte [r12 + AstNode.left]
    shl al, 3

    cmp edx, 1
    je .lm_byte
    cmp edx, 2
    je .lm_word
    cmp edx, 4
    je .lm_dword

.lm_qword:
    mov byte [r13], 0x48
    inc r13
    mov byte [r13], 0x8B
    inc r13
    call emit_modrm_addr_disp
    jmp .cg_next

.lm_dword:
    mov byte [r13], 0x8B
    inc r13
    call emit_modrm_addr_disp
    jmp .cg_next

.lm_word:
    mov word [r13], 0xB70F
    add r13, 2
    call emit_modrm_addr_disp
    jmp .cg_next

.lm_byte:
    mov word [r13], 0xB60F
    add r13, 2
    call emit_modrm_addr_disp
    jmp .cg_next

.emit_store_mem:
    mov edx, dword [r12 + AstNode.len]
    mov r8, qword [r12 + AstNode.left]
    mov r9, qword [r12 + AstNode.right]

    cmp edx, 1
    je .store_byte
    cmp edx, 2
    je .store_word
    cmp edx, 4
    je .store_dword

.store_qword:
    mov byte [r13], 0x48
    inc r13
    mov byte [r13], 0xC7
    inc r13
    xor al, al
    call emit_modrm_addr_disp
    mov rax, qword [r12 + AstNode.value]
    mov dword [r13], eax
    add r13, 4
    jmp .cg_next

.store_dword:
    mov byte [r13], 0xC7
    inc r13
    xor al, al
    call emit_modrm_addr_disp
    mov rax, qword [r12 + AstNode.value]
    mov dword [r13], eax
    add r13, 4
    jmp .cg_next

.store_word:
    mov byte [r13], 0x66
    inc r13
    mov byte [r13], 0xC7
    inc r13
    xor al, al
    call emit_modrm_addr_disp
    mov rax, qword [r12 + AstNode.value]
    mov word [r13], ax
    add r13, 2
    jmp .cg_next

.store_byte:
    mov byte [r13], 0xC6
    inc r13
    xor al, al
    call emit_modrm_addr_disp
    mov rax, qword [r12 + AstNode.value]
    mov byte [r13], al
    inc r13
    jmp .cg_next

.emit_store_reg:
    mov edx, dword [r12 + AstNode.len]
    mov r8, qword [r12 + AstNode.left]
    mov r9, qword [r12 + AstNode.value]
    mov al, byte [r12 + AstNode.right]
    shl al, 3

    cmp edx, 1
    je .sr_byte
    cmp edx, 2
    je .sr_word
    cmp edx, 4
    je .sr_dword

.sr_qword:
    mov byte [r13], 0x48
    inc r13
    mov byte [r13], 0x89
    inc r13
    call emit_modrm_addr_disp
    jmp .cg_next

.sr_dword:
    mov byte [r13], 0x89
    inc r13
    call emit_modrm_addr_disp
    jmp .cg_next

.sr_word:
    mov byte [r13], 0x66
    inc r13
    mov byte [r13], 0x89
    inc r13
    call emit_modrm_addr_disp
    jmp .cg_next

.sr_byte:
    mov byte [r13], 0x88
    inc r13
    call emit_modrm_addr_disp
    jmp .cg_next

.emit_simd_load:
    mov word [r13], 0x100F
    add r13, 2
    mov al, byte [r12 + AstNode.left]
    shl al, 3
    mov r8, qword [r12 + AstNode.right]
    mov r9, qword [r12 + AstNode.value]
    call emit_modrm_addr_disp
    jmp .cg_next

.emit_simd_store:
    mov word [r13], 0x110F
    add r13, 2
    mov al, byte [r12 + AstNode.right]
    shl al, 3
    mov r8, qword [r12 + AstNode.left]
    mov r9, qword [r12 + AstNode.value]
    call emit_modrm_addr_disp
    jmp .cg_next

.emit_simd_binop:
    mov byte [r13], 0x0F
    inc r13
    mov edx, dword [r12 + AstNode.len]
    cmp edx, OP_ADD
    je .emit_addps
    cmp edx, OP_SUB
    je .emit_subps
    cmp edx, OP_MUL
    je .emit_mulps
    cmp edx, OP_XOR
    je .emit_xorps
    jmp .cg_next

.emit_addps:
    mov byte [r13], 0x58
    jmp .emit_xmm_modrm
.emit_subps:
    mov byte [r13], 0x5C
    jmp .emit_xmm_modrm
.emit_mulps:
    mov byte [r13], 0x59
    jmp .emit_xmm_modrm
.emit_xorps:
    mov byte [r13], 0x57

.emit_xmm_modrm:
    inc r13
    mov al, 0xC0
    mov dl, byte [r12 + AstNode.left]
    shl dl, 3
    or al, dl
    or al, byte [r12 + AstNode.right]
    mov byte [r13], al
    inc r13
    jmp .cg_next

.emit_var_imm:
    mov edx, dword [r12 + AstNode.len]
    mov rax, qword [r12 + AstNode.left]
    neg rax

    cmp edx, 1
    je .evi_1
    cmp edx, 2
    je .evi_2
    cmp edx, 4
    je .evi_4

    mov byte [r13], 0x48
    inc r13
    mov byte [r13], 0xC7
    inc r13
    mov byte [r13], 0x85
    inc r13
    mov dword [r13], eax
    add r13, 4
    mov rbx, qword [r12 + AstNode.value]
    mov dword [r13], ebx
    add r13, 4
    jmp .cg_next

.evi_4:
    mov byte [r13], 0xC7
    inc r13
    mov byte [r13], 0x85
    inc r13
    mov dword [r13], eax
    add r13, 4
    mov rbx, qword [r12 + AstNode.value]
    mov dword [r13], ebx
    add r13, 4
    jmp .cg_next

.evi_2:
    mov byte [r13], 0x66
    inc r13
    mov byte [r13], 0xC7
    inc r13
    mov byte [r13], 0x85
    inc r13
    mov dword [r13], eax
    add r13, 4
    mov rbx, qword [r12 + AstNode.value]
    mov word [r13], bx
    add r13, 2
    jmp .cg_next

.evi_1:
    mov byte [r13], 0xC6
    inc r13
    mov byte [r13], 0x85
    inc r13
    mov dword [r13], eax
    add r13, 4
    mov rbx, qword [r12 + AstNode.value]
    mov byte [r13], bl
    inc r13
    jmp .cg_next

.emit_var_reg:
    mov edx, dword [r12 + AstNode.len]
    mov rax, qword [r12 + AstNode.left]
    neg rax

    mov dl, byte [r12 + AstNode.right]
    shl dl, 3
    or dl, 0x85

    mov ebx, dword [r12 + AstNode.len]
    cmp ebx, 1
    je .evr_1
    cmp ebx, 2
    je .evr_2
    cmp ebx, 4
    je .evr_4

    mov byte [r13], 0x48
    inc r13
    mov byte [r13], 0x89
    inc r13
    mov byte [r13], dl
    inc r13
    mov dword [r13], eax
    add r13, 4
    jmp .cg_next

.evr_4:
    mov byte [r13], 0x89
    inc r13
    mov byte [r13], dl
    inc r13
    mov dword [r13], eax
    add r13, 4
    jmp .cg_next

.evr_2:
    mov byte [r13], 0x66
    inc r13
    mov byte [r13], 0x89
    inc r13
    mov byte [r13], dl
    inc r13
    mov dword [r13], eax
    add r13, 4
    jmp .cg_next

.evr_1:
    mov byte [r13], 0x88
    inc r13
    mov byte [r13], dl
    inc r13
    mov dword [r13], eax
    add r13, 4
    jmp .cg_next

.emit_reg_var:
    mov edx, dword [r12 + AstNode.len]
    mov rax, qword [r12 + AstNode.right]
    neg rax

    mov dl, byte [r12 + AstNode.left]
    shl dl, 3
    or dl, 0x85

    mov ebx, dword [r12 + AstNode.len]
    cmp ebx, 1
    je .erv_1
    cmp ebx, 2
    je .erv_2
    cmp ebx, 4
    je .erv_4

    mov byte [r13], 0x48
    inc r13
    mov byte [r13], 0x8B
    inc r13
    mov byte [r13], dl
    inc r13
    mov dword [r13], eax
    add r13, 4
    jmp .cg_next

.erv_4:
    mov byte [r13], 0x8B
    inc r13
    mov byte [r13], dl
    inc r13
    mov dword [r13], eax
    add r13, 4
    jmp .cg_next

.erv_2:
    mov byte [r13], 0x66
    inc r13
    mov byte [r13], 0x8B
    inc r13
    mov byte [r13], dl
    inc r13
    mov dword [r13], eax
    add r13, 4
    jmp .cg_next

.erv_1:
    mov byte [r13], 0x48
    inc r13
    mov word [r13], 0xB60F
    add r13, 2
    mov byte [r13], dl
    inc r13
    mov dword [r13], eax
    add r13, 4
    jmp .cg_next

.emit_lea_var:
    mov al, 0x48
    mov dl, byte [r12 + AstNode.left]
    cmp dl, 8
    jb .el_no_rex_r
    or al, 0x04
.el_no_rex_r:
    mov byte [r13], al
    inc r13
    mov byte [r13], 0x8D
    inc r13
    mov dl, byte [r12 + AstNode.left]
    and dl, 0x07
    shl dl, 3
    or dl, 0x85
    mov byte [r13], dl
    inc r13
    mov rax, qword [r12 + AstNode.value]
    neg rax
    mov dword [r13], eax
    add r13, 4
    jmp .cg_next

.emit_print_str:
    mov byte [r13], 0xEB
    inc r13
    mov eax, dword [r12 + AstNode.len]
    mov byte [r13], al
    inc r13

    push rsi
    push rdi
    push rcx
    mov rsi, qword [r12 + AstNode.value]
    mov rdi, r13
    mov ecx, dword [r12 + AstNode.len]
    rep movsb
    mov r13, rdi
    pop rcx
    pop rdi
    pop rsi

    mov byte [r13], 0x48
    inc r13
    mov byte [r13], 0x8D
    inc r13
    mov byte [r13], 0x35
    inc r13
    mov eax, dword [r12 + AstNode.len]
    neg eax
    sub eax, 7
    mov dword [r13], eax
    add r13, 4

    mov byte [r13], 0xB8
    inc r13
    mov dword [r13], 1
    add r13, 4

    mov byte [r13], 0xBF
    inc r13
    mov dword [r13], 1
    add r13, 4

    mov byte [r13], 0xBA
    inc r13
    mov eax, dword [r12 + AstNode.len]
    mov dword [r13], eax
    add r13, 4

    mov word [r13], 0x050F
    add r13, 2
    jmp .cg_next

.emit_cli:
    mov byte [r13], 0xFA
    inc r13
    jmp .cg_next

.emit_sti:
    mov byte [r13], 0xFB
    inc r13
    jmp .cg_next

.emit_hlt:
    mov byte [r13], 0xF4
    inc r13
    jmp .cg_next

.emit_outb:
    mov edx, dword [r12 + AstNode.len]
    test edx, edx
    jnz .e_outb_reg
    ; outb imm_port, imm_val
    mov word [r13], 0xBA66
    add r13, 2
    mov rax, qword [r12 + AstNode.left]
    mov word [r13], ax
    add r13, 2
    mov byte [r13], 0xB0
    inc r13
    mov rax, qword [r12 + AstNode.right]
    mov byte [r13], al
    inc r13
    mov byte [r13], 0xEE
    inc r13
    jmp .cg_next
.e_outb_reg:
    mov byte [r13], 0xEE       ; out dx, al
    inc r13
    jmp .cg_next

.emit_outw:
    mov edx, dword [r12 + AstNode.len]
    test edx, edx
    jnz .e_outw_reg
    mov word [r13], 0xBA66
    add r13, 2
    mov rax, qword [r12 + AstNode.left]
    mov word [r13], ax
    add r13, 2
    mov word [r13], 0xB866
    add r13, 2
    mov rax, qword [r12 + AstNode.right]
    mov word [r13], ax
    add r13, 2
    mov word [r13], 0xEF66
    add r13, 2
    jmp .cg_next
.e_outw_reg:
    mov word [r13], 0xEF66     ; out dx, ax
    add r13, 2
    jmp .cg_next

.emit_outd:
    mov edx, dword [r12 + AstNode.len]
    test edx, edx
    jnz .e_outd_reg
    mov word [r13], 0xBA66
    add r13, 2
    mov rax, qword [r12 + AstNode.left]
    mov word [r13], ax
    add r13, 2
    mov byte [r13], 0xB8
    inc r13
    mov rax, qword [r12 + AstNode.right]
    mov dword [r13], eax
    add r13, 4
    mov byte [r13], 0xEF
    inc r13
    jmp .cg_next
.e_outd_reg:
    mov byte [r13], 0xEF       ; out dx, eax
    inc r13
    jmp .cg_next

.emit_inb:
    mov edx, dword [r12 + AstNode.len]
    test edx, edx
    jnz .e_inb_reg
    mov word [r13], 0xBA66
    add r13, 2
    mov rax, qword [r12 + AstNode.value]
    mov word [r13], ax
    add r13, 2
.e_inb_reg:
    mov byte [r13], 0xEC       ; in al, dx
    inc r13
    mov byte [r13], 0x48
    inc r13
    mov word [r13], 0xB60F
    add r13, 2
    mov al, 0xC0
    mov dl, byte [r12 + AstNode.left]
    shl dl, 3
    or al, dl
    mov byte [r13], al
    inc r13
    jmp .cg_next

.emit_inw:
    mov edx, dword [r12 + AstNode.len]
    test edx, edx
    jnz .e_inw_reg
    mov word [r13], 0xBA66
    add r13, 2
    mov rax, qword [r12 + AstNode.value]
    mov word [r13], ax
    add r13, 2
.e_inw_reg:
    mov word [r13], 0xED66     ; in ax, dx
    add r13, 2
    mov byte [r13], 0x48
    inc r13
    mov word [r13], 0xB70F
    add r13, 2
    mov al, 0xC0
    mov dl, byte [r12 + AstNode.left]
    shl dl, 3
    or al, dl
    mov byte [r13], al
    inc r13
    jmp .cg_next

.emit_ind:
    mov edx, dword [r12 + AstNode.len]
    test edx, edx
    jnz .e_ind_reg
    mov word [r13], 0xBA66
    add r13, 2
    mov rax, qword [r12 + AstNode.value]
    mov word [r13], ax
    add r13, 2
.e_ind_reg:
    mov byte [r13], 0xED       ; in eax, dx
    inc r13
    mov byte [r13], 0x48
    inc r13
    mov byte [r13], 0x89
    inc r13
    mov al, 0xC0
    mov dl, byte [r12 + AstNode.left]
    and dl, 0x07
    or al, dl
    mov byte [r13], al
    inc r13
    jmp .cg_next

.emit_mov_to_cr:
    mov byte [r13], 0x0F
    inc r13
    mov byte [r13], 0x22       ; mov crX, reg
    inc r13
    mov al, 0xC0
    mov dl, byte [r12 + AstNode.left]
    shl dl, 3
    or al, dl
    mov dl, byte [r12 + AstNode.right]
    and dl, 0x07
    or al, dl
    mov byte [r13], al
    inc r13
    jmp .cg_next

.emit_mov_from_cr:
    mov byte [r13], 0x0F
    inc r13
    mov byte [r13], 0x20       ; mov reg, crX
    inc r13
    mov al, 0xC0
    mov dl, byte [r12 + AstNode.right]
    shl dl, 3
    or al, dl
    mov dl, byte [r12 + AstNode.left]
    and dl, 0x07
    or al, dl
    mov byte [r13], al
    inc r13
    jmp .cg_next

.emit_lidt:
    mov word [r13], 0x010F     ; lidt [rbp - disp32]
    add r13, 2
    mov byte [r13], 0x9D
    inc r13
    mov rax, qword [r12 + AstNode.value]
    neg rax
    mov dword [r13], eax
    add r13, 4
    jmp .cg_next

.emit_lgdt:
    mov word [r13], 0x010F     ; lgdt [rbp - disp32]
    add r13, 2
    mov byte [r13], 0x95
    inc r13
    mov rax, qword [r12 + AstNode.value]
    neg rax
    mov dword [r13], eax
    add r13, 4
    jmp .cg_next

.emit_logic_not:
    mov byte [r13], 0x48
    inc r13
    mov byte [r13], 0x85
    inc r13
    mov al, 0xC0
    mov dl, byte [r12 + AstNode.right]
    shl dl, 3
    or al, dl
    or al, byte [r12 + AstNode.right]
    mov byte [r13], al
    inc r13

    mov word [r13], 0x940F
    add r13, 2
    mov byte [r13], 0xC0
    inc r13

    mov byte [r13], 0x48
    inc r13
    mov word [r13], 0xB60F
    add r13, 2
    mov al, 0xC0
    mov dl, byte [r12 + AstNode.left]
    shl dl, 3
    or al, dl
    mov byte [r13], al
    inc r13
    jmp .cg_next

.emit_logic_or:
    mov byte [r13], 0x48
    inc r13
    mov byte [r13], 0x89
    inc r13
    mov al, 0xC0
    mov dl, byte [r12 + AstNode.right]
    shl dl, 3
    or al, dl
    or al, byte [r12 + AstNode.left]
    mov byte [r13], al
    inc r13

    mov byte [r13], 0x48
    inc r13
    mov byte [r13], 0x09
    inc r13
    mov al, 0xC0
    mov dl, byte [r12 + AstNode.value]
    shl dl, 3
    or al, dl
    or al, byte [r12 + AstNode.left]
    mov byte [r13], al
    inc r13

    mov word [r13], 0x950F
    add r13, 2
    mov byte [r13], 0xC0
    inc r13

    mov byte [r13], 0x48
    inc r13
    mov word [r13], 0xB60F
    add r13, 2
    mov al, 0xC0
    mov dl, byte [r12 + AstNode.left]
    shl dl, 3
    or al, dl
    mov byte [r13], al
    inc r13
    jmp .cg_next

.emit_logic_and:
    mov byte [r13], 0x48
    inc r13
    mov byte [r13], 0x89
    inc r13
    mov al, 0xC0
    mov dl, byte [r12 + AstNode.right]
    shl dl, 3
    or al, dl
    or al, byte [r12 + AstNode.left]
    mov byte [r13], al
    inc r13

    mov byte [r13], 0x48
    inc r13
    mov byte [r13], 0x85
    inc r13
    mov al, 0xC0
    mov dl, byte [r12 + AstNode.left]
    shl dl, 3
    or al, dl
    or al, byte [r12 + AstNode.left]
    mov byte [r13], al
    inc r13

    mov word [r13], 0x950F
    add r13, 2
    mov byte [r13], 0xC0
    inc r13

    mov byte [r13], 0x48
    inc r13
    mov byte [r13], 0x85
    inc r13
    mov al, 0xC0
    mov dl, byte [r12 + AstNode.value]
    shl dl, 3
    or al, dl
    or al, byte [r12 + AstNode.value]
    mov byte [r13], al
    inc r13

    mov word [r13], 0x950F
    add r13, 2
    mov byte [r13], 0xC2
    inc r13

    mov word [r13], 0xD020
    add r13, 2

    mov byte [r13], 0x48
    inc r13
    mov word [r13], 0xB60F
    add r13, 2
    mov al, 0xC0
    mov dl, byte [r12 + AstNode.left]
    shl dl, 3
    or al, dl
    mov byte [r13], al
    inc r13
    jmp .cg_next

.emit_paren_expr:
    mov byte [r13], 0x48
    inc r13
    mov byte [r13], 0x89
    inc r13
    mov al, 0xC0
    mov dl, byte [r12 + AstNode.right]
    shl dl, 3
    or al, dl
    or al, byte [r12 + AstNode.left]
    mov byte [r13], al
    inc r13

    mov edx, dword [r12 + AstNode.len]
    cmp edx, OP_MUL
    je .emit_pe_mul
    cmp edx, OP_SUB
    je .emit_pe_sub

.emit_pe_add:
    mov byte [r13], 0x48
    inc r13
    mov byte [r13], 0x01
    jmp .emit_pe_modrm

.emit_pe_sub:
    mov byte [r13], 0x48
    inc r13
    mov byte [r13], 0x29
    jmp .emit_pe_modrm

.emit_pe_mul:
    mov byte [r13], 0x48
    inc r13
    mov word [r13], 0xAF0F
    add r13, 2
    mov al, 0xC0
    mov dl, byte [r12 + AstNode.left]
    shl dl, 3
    or al, dl
    or al, byte [r12 + AstNode.value]
    mov byte [r13], al
    inc r13
    jmp .cg_next

.emit_pe_modrm:
    inc r13
    mov al, 0xC0
    mov dl, byte [r12 + AstNode.value]
    shl dl, 3
    or al, dl
    or al, byte [r12 + AstNode.left]
    mov byte [r13], al
    inc r13
    jmp .cg_next

.emit_enable_gc:
    mov byte [r13], 0x48
    inc r13
    mov byte [r13], 0xB8
    inc r13
    mov qword [r13], 0x600000
    add r13, 8

    mov byte [r13], 0x48
    inc r13
    mov byte [r13], 0xA3
    inc r13
    mov qword [r13], 0x500000
    add r13, 8
    jmp .cg_next

.emit_gc_new:
    mov byte [r13], 0x48
    inc r13
    mov byte [r13], 0xA1
    inc r13
    mov qword [r13], 0x500000
    add r13, 8

    mov byte [r13], 0x48
    inc r13
    mov word [r13], 0x00C7
    add r13, 2
    mov rax, qword [r12 + AstNode.value]
    mov dword [r13], eax
    add r13, 4

    mov byte [r13], 0x48
    inc r13
    mov word [r13], 0x0481
    add r13, 2
    mov byte [r13], 0x25
    inc r13
    mov dword [r13], 0x500000
    add r13, 4
    mov rax, qword [r12 + AstNode.value]
    add rax, 16
    mov dword [r13], eax
    add r13, 4

    mov byte [r13], 0x48
    inc r13
    mov word [r13], 0xC083
    add r13, 2
    mov byte [r13], 16
    inc r13

    mov al, byte [r12 + AstNode.left]
    test al, al
    jz .cg_next

    mov byte [r13], 0x48
    inc r13
    mov byte [r13], 0x89
    inc r13
    mov al, 0xC0
    or al, byte [r12 + AstNode.left]
    mov byte [r13], al
    inc r13
    jmp .cg_next

.emit_say:
    mov byte [r13], 0xEB
    inc r13
    mov eax, dword [r12 + AstNode.len]
    inc eax
    mov byte [r13], al
    inc r13

    push rsi
    push rdi
    push rcx
    mov rsi, qword [r12 + AstNode.value]
    mov rdi, r13
    mov ecx, dword [r12 + AstNode.len]
    rep movsb
    mov byte [rdi], 0x0A
    inc rdi
    mov r13, rdi
    pop rcx
    pop rdi
    pop rsi

    mov byte [r13], 0x48
    inc r13
    mov byte [r13], 0x8D
    inc r13
    mov byte [r13], 0x35
    inc r13
    mov eax, dword [r12 + AstNode.len]
    inc eax
    neg eax
    sub eax, 7
    mov dword [r13], eax
    add r13, 4

    mov byte [r13], 0xB8
    inc r13
    mov dword [r13], 1
    add r13, 4

    mov byte [r13], 0xBF
    inc r13
    mov dword [r13], 1
    add r13, 4

    mov byte [r13], 0xBA
    inc r13
    mov eax, dword [r12 + AstNode.len]
    inc eax
    mov dword [r13], eax
    add r13, 4

    mov word [r13], 0x050F
    add r13, 2
    jmp .cg_next

.emit_repeat:
    mov byte [r13], 0x48
    inc r13
    mov byte [r13], 0xBB
    inc r13
    mov rax, qword [r12 + AstNode.value]
    mov qword [r13], rax
    add r13, 8

    mov byte [r13], 0x53
    inc r13
    jmp .cg_next

.emit_repeat_end:
    mov byte [r13], 0x5B
    inc r13

    mov byte [r13], 0x48
    inc r13
    mov word [r13], 0xCBFF
    add r13, 2

    mov byte [r13], 0x48
    inc r13
    mov word [r13], 0xFB83
    add r13, 2
    mov byte [r13], 0
    inc r13

    mov word [r13], 0x8E0F
    add r13, 2
    mov dword [r13], 6
    add r13, 4

    mov byte [r13], 0x53
    inc r13

    mov byte [r13], 0xE9
    inc r13
    mov rax, qword [r12 + AstNode.value]
    add rax, 11
    mov rdx, r13
    sub rdx, [code_start_ptr]
    add rdx, 4
    sub rax, rdx
    mov dword [r13], eax
    add r13, 4
    jmp .cg_next

.emit_inline_hex:
    push rsi
    push rcx
    mov rsi, qword [r12 + AstNode.left]
    mov ecx, dword [r12 + AstNode.right]
.hex_scan_loop2:
    test ecx, ecx
    jz .hex_scan_done2
    lodsb
    dec ecx
    cmp al, '#'
    je .h2_comment1
    call is_hex_char
    test ah, ah
    jz .hex_scan_loop2
    mov dl, al
.wait_second:
    test ecx, ecx
    jz .hex_scan_done2
    lodsb
    dec ecx
    cmp al, '#'
    je .h2_comment2
    call is_hex_char
    test ah, ah
    jz .wait_second
    mov dh, al
    push rdx
    mov ah, dl
    mov al, dh
    call decode_hex_byte
    mov byte [r13], dl
    inc r13
    pop rdx
    jmp .hex_scan_loop2

.h2_comment1:
    test ecx, ecx
    jz .hex_scan_done2
    lodsb
    dec ecx
    cmp al, 0x0A
    je .hex_scan_loop2
    jmp .h2_comment1

.h2_comment2:
    test ecx, ecx
    jz .hex_scan_done2
    lodsb
    dec ecx
    cmp al, 0x0A
    je .wait_second
    jmp .h2_comment2

.hex_scan_done2:
    pop rcx
    pop rsi
    jmp .cg_next

.emit_inline_asm:
    mov byte [r13], 0xEB
    inc r13
    mov byte [r13], 24
    inc r13
    mov dword [r13], 0x4D53415B
    add r13, 4
    mov dword [r13], 0x6E49205D
    add r13, 4
    mov dword [r13], 0x656E696C
    add r13, 4
    mov dword [r13], 0x746E6920
    add r13, 4
    mov dword [r13], 0x70656372
    add r13, 4
    mov dword [r13], 0x0A2E6465
    add r13, 4

    mov byte [r13], 0x48
    inc r13
    mov byte [r13], 0x8D
    inc r13
    mov byte [r13], 0x35
    inc r13
    mov dword [r13], -31
    add r13, 4

    mov byte [r13], 0xB8
    inc r13
    mov dword [r13], 1
    add r13, 4

    mov byte [r13], 0xBF
    inc r13
    mov dword [r13], 1
    add r13, 4

    mov byte [r13], 0xBA
    inc r13
    mov dword [r13], 24
    add r13, 4

    mov word [r13], 0x050F
    add r13, 2
    jmp .cg_next

.emit_inline_c:
    mov byte [r13], 0xEB
    inc r13
    mov byte [r13], 24
    inc r13
    mov dword [r13], 0x205D435B
    add r13, 4
    mov dword [r13], 0x696C6E49
    add r13, 4
    mov dword [r13], 0x6920656E
    add r13, 4
    mov dword [r13], 0x7265746E
    add r13, 4
    mov dword [r13], 0x74706563
    add r13, 4
    mov dword [r13], 0x0A2E6465
    add r13, 4

    mov byte [r13], 0x48
    inc r13
    mov byte [r13], 0x8D
    inc r13
    mov byte [r13], 0x35
    inc r13
    mov dword [r13], -31
    add r13, 4

    mov byte [r13], 0xB8
    inc r13
    mov dword [r13], 1
    add r13, 4

    mov byte [r13], 0xBF
    inc r13
    mov dword [r13], 1
    add r13, 4

    mov byte [r13], 0xBA
    inc r13
    mov dword [r13], 24
    add r13, 4

    mov word [r13], 0x050F
    add r13, 2
    jmp .cg_next

; --- СИСТЕМНЫЕ ВЫЗОВЫ ---
.emit_net_listen:
    mov al, byte [r12 + AstNode.len]
    mov rdx, qword [r12 + AstNode.left]
    mov r8b, 0
    call emit_load_syscall_arg

    push rdi
    mov rdi, r13
    push rsi
    push rcx
    mov rsi, net_listen_template
    mov ecx, NET_LISTEN_SIZE
    rep movsb
    pop rcx
    pop rsi
    mov r13, rdi
    pop rdi
    jmp .cg_next

.emit_net_accept:
    mov al, byte [r12 + AstNode.len]
    mov rdx, qword [r12 + AstNode.left]
    mov r8b, 7
    call emit_load_syscall_arg

    mov word [r13], 0xF631
    add r13, 2
    mov word [r13], 0xD231
    add r13, 2
    mov byte [r13], 0xB8
    inc r13
    mov dword [r13], 43
    add r13, 4
    mov word [r13], 0x050F
    add r13, 2
    jmp .cg_next

.emit_sys_write:
    mov eax, 1
    jmp .emit_sys_3args_dispatch

.emit_sys_read:
    mov eax, 0
    jmp .emit_sys_3args_dispatch

.emit_sys_socket:
    mov eax, 41
    jmp .emit_sys_3args_dispatch

.emit_sys_bind:
    mov eax, 49
    jmp .emit_sys_3args_dispatch

.emit_sys_accept:
    mov eax, 43
    jmp .emit_sys_3args_dispatch

.emit_sys_open:
    mov eax, 2
    jmp .emit_sys_3args_dispatch

.emit_sys_sendfile:
    mov al, byte [r12 + AstNode.len]
    mov rdx, qword [r12 + AstNode.left]
    mov r8b, 7
    call emit_load_syscall_arg

    mov al, byte [r12 + AstNode.len + 1]
    mov rdx, qword [r12 + AstNode.right]
    mov r8b, 6
    call emit_load_syscall_arg

    mov byte [r13], 0x31
    inc r13
    mov byte [r13], 0xD2
    inc r13

    mov al, byte [r12 + AstNode.len + 2]
    mov rdx, qword [r12 + AstNode.value]
    mov r8b, 10
    call emit_load_syscall_arg

    mov byte [r13], 0xB8
    inc r13
    mov dword [r13], 40
    add r13, 4

    mov word [r13], 0x050F
    add r13, 2
    jmp .cg_next

.emit_sys_3args_dispatch:
    push rax
    mov al, byte [r12 + AstNode.len]
    mov rdx, qword [r12 + AstNode.left]
    mov r8b, 7
    call emit_load_syscall_arg

    mov al, byte [r12 + AstNode.len + 1]
    mov rdx, qword [r12 + AstNode.right]
    mov r8b, 6
    call emit_load_syscall_arg

    mov al, byte [r12 + AstNode.len + 2]
    mov rdx, qword [r12 + AstNode.value]
    mov r8b, 2
    call emit_load_syscall_arg

    pop rax
    mov byte [r13], 0xB8
    inc r13
    mov dword [r13], eax
    add r13, 4

    mov word [r13], 0x050F
    add r13, 2
    jmp .cg_next

.emit_sys_listen:
    mov al, byte [r12 + AstNode.len]
    mov rdx, qword [r12 + AstNode.left]
    mov r8b, 7
    call emit_load_syscall_arg

    mov al, byte [r12 + AstNode.len + 1]
    mov rdx, qword [r12 + AstNode.right]
    mov r8b, 6
    call emit_load_syscall_arg

    mov byte [r13], 0xB8
    inc r13
    mov dword [r13], 50
    add r13, 4

    mov word [r13], 0x050F
    add r13, 2
    jmp .cg_next

.emit_sys_close:
    mov al, byte [r12 + AstNode.len]
    mov rdx, qword [r12 + AstNode.left]
    mov r8b, 7
    call emit_load_syscall_arg

    mov byte [r13], 0xB8
    inc r13
    mov dword [r13], 3
    add r13, 4

    mov word [r13], 0x050F
    add r13, 2
    jmp .cg_next

.emit_sys_exit:
    mov rax, qword [r12 + AstNode.left]
    test rax, rax
    jnz .ese_from_reg

    mov byte [r13], 0xBF
    inc r13
    mov rax, qword [r12 + AstNode.value]
    mov dword [r13], eax
    add r13, 4
    jmp .ese_syscall

.ese_from_reg:
    mov al, 0x48
    mov dl, byte [r12 + AstNode.right]
    cmp dl, 8
    jb .ese_no_rex_r
    or al, 0x04
.ese_no_rex_r:
    mov byte [r13], al
    inc r13
    mov byte [r13], 0x89
    inc r13
    mov al, 0xC0
    mov dl, byte [r12 + AstNode.right]
    and dl, 0x07
    shl dl, 3
    or al, dl
    or al, 7  
    mov byte [r13], al
    inc r13

.ese_syscall:
    mov byte [r13], 0xB8
    inc r13
    mov dword [r13], 60
    add r13, 4

    mov word [r13], 0x050F
    add r13, 2
    jmp .cg_next

.emit_syscall:
    mov word [r13], 0x050F
    add r13, 2
    jmp .cg_next

.emit_cmp_reg:
    mov byte [r13], 0x48
    inc r13
    mov byte [r13], 0x39
    inc r13
    mov al, 0xC0
    mov dl, byte [r12 + AstNode.right]
    shl dl, 3
    or al, dl
    or al, byte [r12 + AstNode.left]
    mov byte [r13], al
    inc r13
    jmp .cg_next

.emit_cmp_imm:
    mov byte [r13], 0x48
    inc r13
    mov byte [r13], 0x81
    inc r13
    mov al, 0xF8
    or al, byte [r12 + AstNode.left]
    mov byte [r13], al
    inc r13
    mov rax, qword [r12 + AstNode.value]
    mov dword [r13], eax
    add r13, 4
    jmp .cg_next

.emit_jmp:
    mov byte [r13], 0xE9
    inc r13
    call find_rel_offset
    sub rax, 4
    mov dword [r13], eax
    add r13, 4
    jmp .cg_next

.emit_call:
    mov byte [r13], 0xE8
    inc r13
    call find_rel_offset
    sub rax, 4
    mov dword [r13], eax
    add r13, 4
    jmp .cg_next

.emit_jb:
    mov word [r13], 0x820F
    jmp .emit_jcc_rel32
.emit_jae:
    mov word [r13], 0x830F
    jmp .emit_jcc_rel32
.emit_je:
    mov word [r13], 0x840F
    jmp .emit_jcc_rel32
.emit_jne:
    mov word [r13], 0x850F
    jmp .emit_jcc_rel32
.emit_jbe:
    mov word [r13], 0x860F
    jmp .emit_jcc_rel32
.emit_ja:
    mov word [r13], 0x870F
    jmp .emit_jcc_rel32
.emit_jl:
    mov word [r13], 0x8C0F
    jmp .emit_jcc_rel32
.emit_jge:
    mov word [r13], 0x8D0F
    jmp .emit_jcc_rel32
.emit_jle:
    mov word [r13], 0x8E0F
    jmp .emit_jcc_rel32
.emit_jg:
    mov word [r13], 0x8F0F

.emit_jcc_rel32:
    add r13, 2
    call find_rel_offset
    sub rax, 4
    mov dword [r13], eax
    add r13, 4
    jmp .cg_next

.emit_epilogue:
    mov word [r13], 0xFF31
    add r13, 2

    mov byte [r13], 0xB8
    inc r13
    mov dword [r13], 60
    add r13, 4

    mov word [r13], 0x050F
    add r13, 2
    jmp .cg_next

.cg_next:
    add r12, 32
    dec rcx
    jmp .cg_loop

.cg_done:
    mov rax, r13
    sub rax, [code_start_ptr]
    pop rbp
    ret

find_rel_offset:
    push rbx
    push rsi
    push rdi
    push rcx
    mov r8, qword [r12 + AstNode.value]
    add r8, 16
    mov rsi, qword [r8 + Token.ptr]
    mov edx, dword [r8 + Token.len]

    test edx, edx
    jz .target_no_at
    cmp byte [rsi], '@'
    jne .target_no_at
    inc rsi
    dec edx
.target_no_at:

    mov rcx, [labels_count]
    xor rbx, rbx
.search_label:
    test rcx, rcx
    jz .label_not_found
    mov r9, [labels_table + rbx]
    mov rdi, qword [r9 + Token.ptr]
    mov eax, dword [r9 + Token.len]

    test eax, eax
    jz .cand_no_at
    cmp byte [rdi], '@'
    jne .cand_no_at
    inc rdi
    dec eax
.cand_no_at:

    cmp eax, edx
    jne .next_l
    push rcx
    push rsi
    push rdi
    mov ecx, edx
    repe cmpsb
    pop rdi
    pop rsi
    pop rcx
    je .found_l

.next_l:
    add rbx, 16
    dec rcx
    jmp .search_label

.found_l:
    mov rax, [labels_table + rbx + 8]
    mov r10, r13
    sub r10, [code_start_ptr]
    sub rax, r10
    pop rcx
    pop rdi
    pop rsi
    pop rbx
    ret

.label_not_found:
    xor rax, rax
    pop rcx
    pop rdi
    pop rsi
    pop rbx
    ret