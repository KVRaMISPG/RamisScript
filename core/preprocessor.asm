preprocess_file:
.prep_loop:
    mov al, byte [rsi]
    test al, al
    jz .prep_done
    cmp dword [rsi], "incl"
    je .check_inc
.copy:
    movsb
    jmp .prep_loop
.check_inc:
    cmp word [rsi+4], "ud"
    jne .copy
    cmp byte [rsi+6], "e"
    jne .copy
    cmp byte [rsi+7], ' '
    jne .copy
    cmp byte [rsi+8], '"'
    jne .copy
    add rsi, 9
    mov r8, rsi
.find_quote:
    lodsb
    cmp al, '"'
    jne .find_quote
    push rdi
    push rsi
    mov rcx, rsi
    sub rcx, r8
    dec rcx
    mov rdi, inc_filename
    mov rsi, r8
    rep movsb
    mov byte [rdi], 0
    mov rax, SYS_OPEN
    mov rdi, inc_filename
    mov rsi, O_RDONLY
    xor rdx, rdx
    syscall
    test rax, rax
    js .prep_err
    mov r9, rax
    
    pop rsi
    pop rdi
    
    push rsi
    push rdi         
    
    mov rax, SYS_READ
    mov rsi, rdi
    mov rdi, r9
    mov rdx, 1048576
    syscall
    mov r10, rax
    
    mov rax, SYS_CLOSE
    mov rdi, r9       
    syscall
    
    pop rdi         
    pop rsi
    
    add rdi, r10
    mov byte [rdi], 0x0A 
    inc rdi
    jmp .prep_loop
    
.prep_done:
    mov byte [rdi], 0
    ret
.prep_err:
    pop rsi
    pop rdi
    jmp .prep_loop