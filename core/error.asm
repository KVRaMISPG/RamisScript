align 8

report_error:
    cmp rsi, -9
    jne .chk_e_other
    cmp byte [lang_ru], 1
    je .e_net_ru
    mov rsi, msg_err_net_en
    mov rdx, msg_err_net_en_len
    jmp .do_print_err
.e_net_ru:
    mov rsi, msg_err_net_ru
    mov rdx, msg_err_net_ru_len
    jmp .do_print_err
.chk_e_other:
    push rbp
    mov rbp, rsp
    push rdi
    push rsi

    mov rsi, preproc_buf
    mov r8, 1
    mov r9, 1
    mov r10, rsi

.scan_loop:
    cmp rsi, rdi
    jae .scan_done
    mov al, byte [rsi]
    cmp al, 0x0A
    jne .not_nl
    inc r8
    mov r9, 1
    inc rsi
    mov r10, rsi
    jmp .scan_loop
.not_nl:
    inc r9
    inc rsi
    jmp .scan_loop
    
.scan_done:
    push r8
    push r9
    push r10

    mov rax, [rbp - 16]
    cmp rax, -1
    je .print_err_loser
    cmp rax, -2
    je .print_err_syntax
    cmp rax, -3
    je .print_err_osdev
    cmp rax, -4
    je .print_err_sys
    cmp rax, -5
    je .print_err_vars
    cmp rax, -6
    je .print_err_logic
    cmp rax, -7
    je .print_err_gc
    cmp rax, -8
    je .print_err_kids
    jmp .print_line

.print_err_loser:
    cmp byte [lang_ru], 1
    je .loser_ru
    mov rsi, msg_err_loser_en
    mov rdx, msg_err_loser_en_len
    jmp .do_print_err
.loser_ru:
    mov rsi, msg_err_loser_ru
    mov rdx, msg_err_loser_ru_len
    jmp .do_print_err

.print_err_syntax:
    cmp byte [lang_ru], 1
    je .syn_ru
    mov rsi, msg_err_syn_en
    mov rdx, msg_err_syn_en_len
    jmp .do_print_err
.syn_ru:
    mov rsi, msg_err_syn_ru
    mov rdx, msg_err_syn_ru_len
    jmp .do_print_err

.print_err_osdev:
    cmp byte [lang_ru], 1
    je .osdev_ru
    mov rsi, msg_err_osdev_en
    mov rdx, msg_err_osdev_en_len
    jmp .do_print_err
.osdev_ru:
    mov rsi, msg_err_osdev_ru
    mov rdx, msg_err_osdev_ru_len
    jmp .do_print_err

.print_err_sys:
    cmp byte [lang_ru], 1
    je .sys_ru
    mov rsi, msg_err_sys_en
    mov rdx, msg_err_sys_en_len
    jmp .do_print_err
.sys_ru:
    mov rsi, msg_err_sys_ru
    mov rdx, msg_err_sys_ru_len
    jmp .do_print_err

.print_err_vars:
    cmp byte [lang_ru], 1
    je .vars_ru
    mov rsi, msg_err_vars_en
    mov rdx, msg_err_vars_en_len
    jmp .do_print_err
.vars_ru:
    mov rsi, msg_err_vars_ru
    mov rdx, msg_err_vars_ru_len
    jmp .do_print_err

.print_err_logic:
    cmp byte [lang_ru], 1
    je .logic_ru
    mov rsi, msg_err_logic_en
    mov rdx, msg_err_logic_en_len
    jmp .do_print_err
.logic_ru:
    mov rsi, msg_err_logic_ru
    mov rdx, msg_err_logic_ru_len
    jmp .do_print_err

.print_err_gc:
    cmp byte [lang_ru], 1
    je .gc_ru
    mov rsi, msg_err_gc_en
    mov rdx, msg_err_gc_en_len
    jmp .do_print_err
.gc_ru:
    mov rsi, msg_err_gc_ru
    mov rdx, msg_err_gc_ru_len
    jmp .do_print_err

.print_err_kids:
    cmp byte [lang_ru], 1
    je .kids_ru
    mov rsi, msg_err_kids_en
    mov rdx, msg_err_kids_en_len
    jmp .do_print_err
.kids_ru:
    mov rsi, msg_err_kids_ru
    mov rdx, msg_err_kids_ru_len

.do_print_err:
    mov rax, SYS_WRITE
    mov rdi, 1
    syscall

.print_line:
    pop r10
    mov rsi, r10
    xor rcx, rcx
.find_nl:
    mov al, byte [rsi + rcx]
    test al, al
    jz .nl_found
    cmp al, 0x0A
    je .nl_found
    inc rcx
    jmp .find_nl
.nl_found:
    mov rax, SYS_WRITE
    mov rdi, 1
    mov rdx, rcx
    syscall

    mov rax, SYS_WRITE
    mov rdi, 1
    mov rsi, nl_char
    mov rdx, 1
    syscall

    pop r9
    pop r8
    dec r9
    cmp r9, 0
    jle .print_caret

.print_spaces:
    push r9
    mov rax, SYS_WRITE
    mov rdi, 1
    mov rsi, space_char
    mov rdx, 1
    syscall
    pop r9
    dec r9
    jnz .print_spaces

.print_caret:
    mov rax, SYS_WRITE
    mov rdi, 1
    mov rsi, caret_char
    mov rdx, 2
    syscall

    pop rsi
    pop rdi
    pop rbp
    ret