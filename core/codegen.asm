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
    cmp eax, AST_NODE_INB
    je .p1_inb
    cmp eax, AST_NODE_INW
    je .p1_inw
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
    cmp eax, AST_NODE_SYS_WRITE
    je .p1_sys_call3
    cmp eax, AST_NODE_SYS_READ
    je .p1_sys_call3
    cmp eax, AST_NODE_SYS_EXIT
    je .p1_sys_exit
    cmp eax, AST_NODE_VAR_ASSIGN_IMM
    je .p1_var_imm
    cmp eax, AST_NODE_VAR_ASSIGN_REG
    je .p1_var_reg
    cmp eax, AST_NODE_REG_ASSIGN_VAR
    je .p1_reg_var
    cmp eax, AST_NODE_RETURN
    je .p1_return
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
    add r14, 7
    jmp .p1_next
.p1_inb:
    add r14, 9
    jmp .p1_next
.p1_inw:
    add r14, 10
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
    je .p1_wait_h2
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

.p1_sys_call3:
    add r14, 18
    jmp .p1_next
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

.p1_return:
    add r14, 5
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
    cmp eax, AST_NODE_OUTB
    je .emit_outb
    cmp eax, AST_NODE_INB
    je .emit_inb
    cmp eax, AST_NODE_INW
    je .emit_inw
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
    cmp eax, AST_NODE_SYS_WRITE
    je .emit_sys_write
    cmp eax, AST_NODE_SYS_READ
    je .emit_sys_read
    cmp eax, AST_NODE_SYS_EXIT
    je .emit_sys_exit
    cmp eax, AST_NODE_VAR_ASSIGN_IMM
    je .emit_var_imm
    cmp eax, AST_NODE_VAR_ASSIGN_REG
    je .emit_var_reg
    cmp eax, AST_NODE_REG_ASSIGN_VAR
    je .emit_reg_var
    cmp eax, AST_NODE_RETURN
    je .emit_epilogue
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
    mov byte [r13], 0x48
    inc r13
    mov al, 0xB8
    add al, byte [r12 + AstNode.len]
    mov byte [r13], al
    inc r13
    mov rax, qword [r12 + AstNode.value]
    mov qword [r13], rax
    add r13, 8
    jmp .cg_next

.emit_assign_reg:
    mov byte [r13], 0x48
    inc r13
    mov byte [r13], 0x89
    inc r13
    mov al, 0xC0
    mov dl, byte [r12 + AstNode.value]
    shl dl, 3
    or al, dl
    or al, byte [r12 + AstNode.len]
    mov byte [r13], al
    inc r13
    jmp .cg_next

.emit_binop_reg:
    mov edx, dword [r12 + AstNode.len]
    cmp edx, OP_ADD
    je .emit_add_r
    cmp edx, OP_SUB
    je .emit_sub_r
    cmp edx, OP_MUL
    je .emit_mul_r
    cmp edx, OP_XOR
    je .emit_xor_r
    cmp edx, OP_AND
    je .emit_and_r
    jmp .cg_next
.emit_add_r:
    mov byte [r13], 0x48
    inc r13
    mov byte [r13], 0x01
    jmp .emit_modrm_r
.emit_sub_r:
    mov byte [r13], 0x48
    inc r13
    mov byte [r13], 0x29
    jmp .emit_modrm_r
.emit_xor_r:
    mov byte [r13], 0x48
    inc r13
    mov byte [r13], 0x31
    jmp .emit_modrm_r
.emit_and_r:
    mov byte [r13], 0x48
    inc r13
    mov byte [r13], 0x21
    jmp .emit_modrm_r

.emit_mul_r:
    mov byte [r13], 0x48
    inc r13
    mov word [r13], 0xAF0F
    add r13, 2
    mov al, 0xC0
    mov dl, byte [r12 + AstNode.left]
    shl dl, 3
    or al, dl
    or al, byte [r12 + AstNode.right]
    mov byte [r13], al
    inc r13
    jmp .cg_next

.emit_modrm_r:
    inc r13
    mov al, 0xC0
    mov dl, byte [r12 + AstNode.right]
    shl dl, 3
    or al, dl
    or al, byte [r12 + AstNode.left]
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

.emit_inb:
    mov word [r13], 0xBA66
    add r13, 2
    mov rax, qword [r12 + AstNode.value]
    mov word [r13], ax
    add r13, 2

    mov byte [r13], 0xEC
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
    mov word [r13], 0xBA66
    add r13, 2
    mov rax, qword [r12 + AstNode.value]
    mov word [r13], ax
    add r13, 2

    mov word [r13], 0xED66
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

.emit_sys_write:
    mov byte [r13], 0xB8
    inc r13
    mov dword [r13], 1
    add r13, 4
    jmp .emit_sys_3args_body

.emit_sys_read:
    mov byte [r13], 0xB8
    inc r13
    mov dword [r13], 0
    add r13, 4

.emit_sys_3args_body:
    mov byte [r13], 0x48
    inc r13
    mov byte [r13], 0x89
    inc r13
    mov al, 0xC0
    mov dl, byte [r12 + AstNode.left]
    shl dl, 3
    or al, dl
    or al, 7
    mov byte [r13], al
    inc r13

    mov byte [r13], 0x48
    inc r13
    mov byte [r13], 0x89
    inc r13
    mov al, 0xC0
    mov dl, byte [r12 + AstNode.right]
    shl dl, 3
    or al, dl
    or al, 6
    mov byte [r13], al
    inc r13

    mov byte [r13], 0xBA
    inc r13
    mov rax, qword [r12 + AstNode.value]
    mov dword [r13], eax
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
    mov byte [r13], 0x48
    inc r13
    mov byte [r13], 0x89
    inc r13
    mov al, 0xC0
    mov dl, byte [r12 + AstNode.right]
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
    mov word [r13], 0x8948
    add r13, 2
    mov byte [r13], 0xEC
    inc r13
    mov byte [r13], 0x5D
    inc r13
    mov byte [r13], 0xC3
    inc r13
    jmp .cg_next

.cg_next:
    add r12, 32
    dec rcx
    jmp .cg_loop

.cg_done:
    mov rax, r13
    sub rax, rdi
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