align 8

dump_hex_code:
    push rbp
    mov rbp, rsp
    push rbx
    push r12
    push r13
    push r14
    push r15

    mov r14, rsi
    mov r15, rcx
    xor r12, r12

.row_loop:
    cmp r12, r15
    jae .dump_done

    mov rax, 0x00400078
    add rax, r12
    call print_addr_header

    xor r13, r13
.byte_loop:
    cmp r12, r15
    jae .end_row

    mov al, byte [r14 + r12]
    call print_hex_byte
    inc r12
    inc r13
    cmp r13, 16
    je .end_row
    jmp .byte_loop

.end_row:
    mov rax, SYS_WRITE
    mov rdi, 1
    mov rsi, nl_char
    mov rdx, 1
    syscall
    jmp .row_loop

.dump_done:
    pop r15
    pop r14
    pop r13
    pop r12
    pop rbx
    pop rbp
    ret

print_addr_header:
    push rax
    push rcx
    push rdx
    
    ; Формируем шаблон "[0x00000000]  " в безопасном буфере inc_filename
    mov dword [inc_filename], 0x3078305B      ; "[0x0"
    mov dword [inc_filename+4], 0x30303030    ; "0000"
    mov dword [inc_filename+8], 0x205D3030    ; "00] "
    mov word [inc_filename+12], 0x2020        ; "  "
    
    mov ecx, 8
.addr_loop:
    mov edx, eax
    and edx, 0x0F
    cmp dl, 9
    jbe .a_digit
    add dl, 'A' - 10
    jmp .a_store
.a_digit:
    add dl, '0'
.a_store:
    mov byte [inc_filename + 2 + rcx], dl
    shr eax, 4
    dec ecx
    jnz .addr_loop

    mov rax, SYS_WRITE
    mov rdi, 1
    mov rsi, inc_filename
    mov rdx, 14
    syscall

    pop rdx
    pop rcx
    pop rax
    ret

print_hex_byte:
    push rax
    push rdx
    mov ah, al
    shr al, 4
    cmp al, 9
    jbe .h1
    add al, 'A' - 10
    jmp .s1
.h1:
    add al, '0'
.s1:
    mov [inc_filename], al
    mov al, ah
    and al, 0x0F
    cmp al, 9
    jbe .h2
    add al, 'A' - 10
    jmp .s2
.h2:
    add al, '0'
.s2:
    mov [inc_filename + 1], al
    mov byte [inc_filename + 2], ' '

    mov rax, SYS_WRITE
    mov rdi, 1
    mov rsi, inc_filename
    mov rdx, 3
    syscall
    pop rdx
    pop rax
    ret