align 8

dict_xmm:
    db 4, "xmm0", 0
    db 4, "xmm1", 1
    db 4, "xmm2", 2
    db 4, "xmm3", 3
    db 4, "xmm4", 4
    db 4, "xmm5", 5
    db 4, "xmm6", 6
    db 4, "xmm7", 7
    db 0

dict_registers:
    db 3, "rax", 0
    db 3, "rcx", 1
    db 3, "rdx", 2
    db 3, "rbx", 3
    db 3, "rsp", 4
    db 3, "rbp", 5
    db 3, "rsi", 6
    db 3, "rdi", 7
    db 0

dict_keywords:
    db 4, "mode"
    db 5, "print"
    db 3, "sub"
    db 2, "fn"
    db 3, "end"
    db 2, "do"
    db 6, "return"
    db 3, "mut"
    db 4, "byte"
    db 4, "word"
    db 5, "dword"
    db 5, "qword"
    db 7, "syscall"
    db 3, "cmp"
    db 3, "jmp"
    db 3, "jne"
    db 2, "je"
    db 2, "jb"
    db 3, "jae"
    db 2, "jl"
    db 3, "jle"
    db 2, "jg"
    db 3, "jge"
    db 2, "ja"
    db 3, "jbe"
    db 4, "call"
    db 3, "cli"
    db 3, "sti"
    db 3, "hlt"
    db 4, "outb"
    db 3, "sys"
    db 5, "write"
    db 4, "read"
    db 4, "exit"
    db 6, "enable"
    db 2, "GC"
    db 3, "for"
    db 6, "BLOCKS"
    db 8, "assembly"
    db 3, "hex"
    db 1, "C"
    db 3, "new"
    db 3, "say"
    db 6, "repeat"
    db 4, "push"
    db 3, "pop"
    db 0

is_alpha:
    xor ah, ah
    cmp al, 'A'
    jb .done
    cmp al, 'Z'
    jbe .yes
    cmp al, 'a'
    jb .done
    cmp al, 'z'
    ja .done
.yes:
    mov ah, 1
.done:
    ret

is_digit:
    xor ah, ah
    cmp al, '0'
    jb .done
    cmp al, '9'
    ja .done
    mov ah, 1
.done:
    ret

is_alnum:
    call is_alpha
    test ah, ah
    jnz .done
    call is_digit
.done:
    ret

tokenize:
    push rbp
    mov rbp, rsp
    sub rsp, 256
    push rbx
    push r12
    push r13

    xor rcx, rcx
    mov r12, 1
    xor r13, r13
    xor rbx, rbx
    mov qword [rbp - 256], 0

.next_char:
    mov al, byte [rsi]
    test al, al
    jz .eof

    cmp al, 0Ah
    je .handle_newline
    cmp al, 0Dh
    je .skip

    cmp r12, 1
    jne .normal_char

    cmp al, 20h
    je .inc_space
    cmp al, 09h
    je .inc_tab

    cmp al, '#'
    je .handle_comment

    call .process_indent
    mov r12, 0

.normal_char:
    cmp al, 20h
    je .skip
    cmp al, 09h
    je .skip

    cmp al, '#'
    je .handle_comment

    cmp al, '"'
    je .parse_string

    cmp al, '@'
    je .parse_label

    cmp word [rsi], 0x3A3A
    je .op2
    cmp word [rsi], 0x3E2D
    je .op2
    cmp word [rsi], 0x3E3E
    je .op2
    cmp word [rsi], 0x3C3C
    je .op2
    cmp word [rsi], 0x2626
    je .op2
    cmp word [rsi], 0x7C7C
    je .op2

    cmp al, '='
    je .op1
    cmp al, '+'
    je .op1
    cmp al, '-'
    je .op1
    cmp al, '*'
    je .op1
    cmp al, '/'
    je .op1
    cmp al, '^'
    je .op1
    cmp al, '&'
    je .op1
    cmp al, '|'
    je .op1
    cmp al, '!'
    je .op1

    cmp al, '('
    je .delim
    cmp al, ')'
    je .delim
    cmp al, '['
    je .delim
    cmp al, ']'
    je .delim
    cmp al, '{'
    je .delim
    cmp al, '}'
    je .delim
    cmp al, ':'
    je .delim
    cmp al, ','
    je .delim
    cmp al, '.'
    je .delim

    call is_alpha
    test ah, ah
    jnz .parse_id

    call is_digit
    test ah, ah
    jnz .parse_num

    jmp .skip

.inc_space:
    inc r13
    inc rsi
    jmp .next_char

.inc_tab:
    add r13, 4
    inc rsi
    jmp .next_char

.handle_newline:
    mov r12, 1
    xor r13, r13
    inc rsi
    jmp .next_char

.process_indent:
    mov r11, qword [rbp - 256 + rbx * 8]
    cmp r13, r11
    jg .do_indent
    jl .do_dedent
    ret

.do_indent:
    cmp rbx, 30
    jge .indent_ret
    inc rbx
    mov qword [rbp - 256 + rbx * 8], r13
    mov dword [rdi + Token.type], TOKEN_INDENT
    mov dword [rdi + Token.len], 0
    mov qword [rdi + Token.ptr], rsi
    add rdi, 16
    inc rcx
.indent_ret:
    ret

.do_dedent:
    mov dword [rdi + Token.type], TOKEN_DEDENT
    mov dword [rdi + Token.len], 0
    mov qword [rdi + Token.ptr], rsi
    add rdi, 16
    inc rcx
    dec rbx
    mov r11, qword [rbp - 256 + rbx * 8]
    cmp r13, r11
    jl .do_dedent
    ret

.parse_string:
    inc rsi
    mov r8, rsi
    mov r10, rsi
.str_loop:
    mov al, byte [rsi]
    test al, al
    jz .str_done
    cmp al, '"'
    je .str_done
    cmp al, '\'
    jne .str_put
    cmp byte [rsi + 1], 'n'
    jne .str_chk_t
    mov byte [r10], 0x0A
    inc r10
    add rsi, 2
    jmp .str_loop
.str_chk_t:
    cmp byte [rsi + 1], 't'
    jne .str_put
    mov byte [r10], 0x09
    inc r10
    add rsi, 2
    jmp .str_loop
.str_put:
    mov byte [r10], al
    inc r10
    inc rsi
    jmp .str_loop
.str_done:
    mov r9, r10
    sub r9, r8
    cmp byte [rsi], '"'
    jne .write_str_tok
    inc rsi
.write_str_tok:
    mov dword [rdi + Token.type], TOKEN_STRING
    mov dword [rdi + Token.len], r9d
    mov qword [rdi + Token.ptr], r8
    add rdi, 16
    inc rcx
    jmp .next_char

.parse_label:
    mov r8, rsi
.label_loop:
    inc rsi
    mov al, byte [rsi]
    cmp al, '_'
    je .label_loop
    call is_alnum
    test ah, ah
    jnz .label_loop

    mov r9, rsi
    sub r9, r8
    mov dword [rdi + Token.type], TOKEN_IDENTIFIER
    mov dword [rdi + Token.len], r9d
    mov qword [rdi + Token.ptr], r8
    add rdi, 16
    inc rcx
    jmp .next_char

.op2:
    mov dword [rdi + Token.type], TOKEN_OPERATOR
    mov dword [rdi + Token.len], 2
    mov qword [rdi + Token.ptr], rsi
    add rdi, 16
    inc rcx
    add rsi, 2
    jmp .next_char

.op1:
    mov dword [rdi + Token.type], TOKEN_OPERATOR
    mov dword [rdi + Token.len], 1
    mov qword [rdi + Token.ptr], rsi
    add rdi, 16
    inc rcx
    inc rsi
    jmp .next_char

.delim:
    mov dword [rdi + Token.type], TOKEN_DELIMITER
    mov dword [rdi + Token.len], 1
    mov qword [rdi + Token.ptr], rsi
    add rdi, 16
    inc rcx
    inc rsi
    jmp .next_char

.skip:
    inc rsi
    jmp .next_char

.handle_comment:
    inc rsi
    cmp byte [rsi], '|'
    je .block_comment

.line_comment:
    mov al, byte [rsi]
    test al, al
    jz .eof
    cmp al, 0Ah
    je .handle_newline
    inc rsi
    jmp .line_comment

.block_comment:
    inc rsi
.block_loop:
    mov al, byte [rsi]
    test al, al
    jz .eof
    cmp al, 0Ah
    je .bc_nl
    cmp al, '|'
    jne .bc_next
    cmp byte [rsi + 1], '#'
    jne .bc_next
    add rsi, 2
    jmp .next_char
.bc_nl:
    mov r12, 1
    xor r13, r13
.bc_next:
    inc rsi
    jmp .block_loop

.parse_num:
    mov r8, rsi
.num_loop:
    inc rsi
    mov al, byte [rsi]
    call is_alnum
    test ah, ah
    jnz .num_loop

    mov r9, rsi
    sub r9, r8
    mov dword [rdi + Token.type], TOKEN_NUMBER
    mov dword [rdi + Token.len], r9d
    mov qword [rdi + Token.ptr], r8
    add rdi, 16
    inc rcx
    jmp .next_char

.parse_id:
    mov r8, rsi
.id_loop:
    inc rsi
    mov al, byte [rsi]
    cmp al, '_'
    je .id_loop
    call is_alnum
    test ah, ah
    jnz .id_loop

    mov r9, rsi
    sub r9, r8

    mov r10, dict_xmm
.check_xmm:
    mov al, byte [r10]
    test al, al
    jz .not_xmm
    cmp al, r9b
    jne .next_xmm

    push rsi
    push rdi
    push rcx
    inc r10
    mov rsi, r10
    mov rdi, r8
    mov rcx, r9
    repe cmpsb
    pop rcx
    pop rdi
    pop rsi
    je .is_xmm

    dec r10
.next_xmm:
    movzx r11, byte [r10]
    add r10, r11
    add r10, 2
    jmp .check_xmm

.is_xmm:
    mov dword [rdi + Token.type], TOKEN_XMM
    movzx eax, byte [r10 + r9]
    mov dword [rdi + Token.len], eax
    mov qword [rdi + Token.ptr], r8
    add rdi, 16
    inc rcx
    jmp .next_char

.not_xmm:
    mov r10, dict_registers
.check_reg:
    mov al, byte [r10]
    test al, al
    jz .not_reg
    cmp al, r9b
    jne .next_reg

    push rsi
    push rdi
    push rcx
    inc r10
    mov rsi, r10
    mov rdi, r8
    mov rcx, r9
    repe cmpsb
    pop rcx
    pop rdi
    pop rsi
    je .is_reg

    dec r10
.next_reg:
    movzx r11, byte [r10]
    add r10, r11
    add r10, 2
    jmp .check_reg

.is_reg:
    mov dword [rdi + Token.type], TOKEN_REGISTER
    movzx eax, byte [r10 + r9]
    mov dword [rdi + Token.len], eax
    mov qword [rdi + Token.ptr], r8
    add rdi, 16
    inc rcx
    jmp .next_char

.not_reg:
    mov r10, dict_keywords
.check_kw:
    mov al, byte [r10]
    test al, al
    jz .not_kw
    cmp al, r9b
    jne .next_kw

    push rsi
    push rdi
    push rcx
    inc r10
    mov rsi, r10
    mov rdi, r8
    mov rcx, r9
    repe cmpsb
    pop rcx
    pop rdi
    pop rsi
    je .is_kw

    dec r10
.next_kw:
    movzx r11, byte [r10]
    inc r11
    add r10, r11
    jmp .check_kw

.is_kw:
    mov dword [rdi + Token.type], TOKEN_KEYWORD
    mov dword [rdi + Token.len], r9d
    mov qword [rdi + Token.ptr], r8
    add rdi, 16
    inc rcx
    jmp .next_char

.not_kw:
    mov dword [rdi + Token.type], TOKEN_IDENTIFIER
    mov dword [rdi + Token.len], r9d
    mov qword [rdi + Token.ptr], r8
    add rdi, 16
    inc rcx
    jmp .next_char

.eof:
.eof_dedent_loop:
    test rbx, rbx
    jz .eof_finish
    mov dword [rdi + Token.type], TOKEN_DEDENT
    mov dword [rdi + Token.len], 0
    mov qword [rdi + Token.ptr], rsi
    add rdi, 16
    inc rcx
    dec rbx
    jmp .eof_dedent_loop

.eof_finish:
    mov dword [rdi + Token.type], TOKEN_EOF
    mov dword [rdi + Token.len], 0
    mov qword [rdi + Token.ptr], 0
    inc rcx
    mov rax, rcx

    pop r13
    pop r12
    pop rbx
    mov rsp, rbp
    pop rbp
    ret
