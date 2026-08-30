align 8

find_var:
    push rbx
    push rsi
    push rdi
    push rcx
    mov rsi, r8
    mov ecx, edx

    mov rbx, [vars_count]
    test rbx, rbx
    jz .not_found

    xor r10, r10
.search_loop:
    mov rdi, [vars_table + r10]
    mov eax, dword [vars_table + r10 + 8]
    cmp eax, ecx
    jne .next_var

    push rcx
    push rsi
    push rdi
    repe cmpsb
    pop rdi
    pop rsi
    pop rcx
    je .found

.next_var:
    add r10, 32
    dec rbx
    jnz .search_loop

.not_found:
    xor rax, rax
    pop rcx
    pop rdi
    pop rsi
    pop rbx
    ret

.found:
    mov rax, r10
    add rax, vars_table
    pop rcx
    pop rdi
    pop rsi
    pop rbx
    ret

parse_number_val:
    push rbx
    push rsi
    mov rsi, r8
    mov ecx, edx
    xor rax, rax
    xor rbx, rbx

    cmp ecx, 2
    jbe .dec_loop
    cmp byte [rsi], '0'
    jne .dec_loop
    mov dl, byte [rsi + 1]
    cmp dl, 'x'
    je .is_hex
    cmp dl, 'X'
    jne .dec_loop

.is_hex:
    add rsi, 2
    sub ecx, 2
.hex_loop:
    test ecx, ecx
    jz .done
    mov bl, byte [rsi]
    cmp bl, '0'
    jb .done
    cmp bl, '9'
    jbe .hex_digit
    cmp bl, 'a'
    jb .hex_upper
    cmp bl, 'f'
    ja .done
    sub bl, 'a' - 10
    jmp .hex_accum
.hex_upper:
    cmp bl, 'A'
    jb .done
    cmp bl, 'F'
    ja .done
    sub bl, 'A' - 10
    jmp .hex_accum
.hex_digit:
    sub bl, '0'
.hex_accum:
    shl rax, 4
    or rax, rbx
    inc rsi
    dec ecx
    jmp .hex_loop

.dec_loop:
    test ecx, ecx
    jz .done
    mov bl, byte [rsi]
    cmp bl, '0'
    jb .done
    cmp bl, '9'
    ja .done
    sub bl, '0'
    imul rax, 10
    add rax, rbx
    inc rsi
    dec ecx
    jmp .dec_loop

.done:
    pop rsi
    pop rbx
    ret

parse_program:
    push rbp
    mov rbp, rsp
    mov r12, rsi
    mov r13, rdi
    mov byte [is_loser_mode], 0
    mov byte [is_osdev_mode], 0
    mov byte [is_sys_mode], 0
    mov byte [is_vars_mode], 0
    mov byte [is_logic_mode], 0
    mov byte [is_kids_mode], 0
    mov byte [is_gc_enabled], 0
    mov byte [is_blocks_enabled], 0
    mov qword [vars_count], 0
    mov qword [curr_var_offset], 0
    mov qword [repeat_depth], 0

.loop:
    mov eax, dword [r12 + Token.type]
    cmp eax, TOKEN_EOF
    je .done

    cmp eax, TOKEN_INDENT
    je .skip_indent_tok
    cmp eax, TOKEN_DEDENT
    je .skip_indent_tok

    cmp eax, TOKEN_REGISTER
    je .handle_reg

    cmp eax, TOKEN_XMM
    je .handle_xmm

    cmp eax, TOKEN_KEYWORD
    je .handle_kw

    cmp eax, TOKEN_DELIMITER
    je .handle_delim_store

    cmp eax, TOKEN_IDENTIFIER
    jne .err_syntax

    mov r8, qword [r12 + Token.ptr]
    cmp byte [r8], '@'
    je .parse_label_decl

    mov eax, dword [r12 + 16 + Token.type]
    cmp eax, TOKEN_OPERATOR
    jne .err_syntax
    mov r9, qword [r12 + 16 + Token.ptr]
    cmp word [r9], 0x3A3A
    je .parse_decl_header

    cmp byte [r9], '='
    je .parse_var_reassign
    jmp .err_syntax

.skip_indent_tok:
    add r12, 16
    jmp .loop

.parse_decl_header:
    mov eax, dword [r12 + 32 + Token.type]
    cmp eax, TOKEN_KEYWORD
    jne .err_syntax
    mov r8, qword [r12 + 32 + Token.ptr]
    cmp byte [r8], 's'
    je .parse_sub
    cmp byte [r8], 'f'
    je .parse_fn
    jmp .err_syntax

.parse_var_reassign:
    mov r8, qword [r12 + Token.ptr]
    mov edx, dword [r12 + Token.len]
    call find_var
    test rax, rax
    jz .err_syntax

    mov r14, rax
    mov eax, dword [r12 + 32 + Token.type]
    cmp eax, TOKEN_NUMBER
    je .var_reassign_num
    cmp eax, TOKEN_REGISTER
    je .var_reassign_reg
    jmp .err_syntax

.var_reassign_num:
    mov r8, qword [r12 + 32 + Token.ptr]
    mov edx, dword [r12 + 32 + Token.len]
    call parse_number_val

    mov dword [r13 + AstNode.type], AST_NODE_VAR_ASSIGN_IMM
    mov edx, dword [r14 + 24]
    mov dword [r13 + AstNode.len], edx
    mov rdx, qword [r14 + 16]
    mov qword [r13 + AstNode.left], rdx
    mov qword [r13 + AstNode.value], rax
    add r13, 32
    add r12, 48
    jmp .loop

.var_reassign_reg:
    mov dword [r13 + AstNode.type], AST_NODE_VAR_ASSIGN_REG
    mov edx, dword [r14 + 24]
    mov dword [r13 + AstNode.len], edx
    mov rdx, qword [r14 + 16]
    mov qword [r13 + AstNode.left], rdx
    movzx rdx, byte [r12 + 32 + Token.len]
    mov qword [r13 + AstNode.right], rdx
    add r13, 32
    add r12, 48
    jmp .loop

.parse_label_decl:
    mov dword [r13 + AstNode.type], AST_NODE_LABEL
    mov eax, dword [r12 + Token.len]
    mov dword [r13 + AstNode.len], eax
    mov qword [r13 + AstNode.value], r12
    mov qword [r13 + AstNode.left], 0
    mov qword [r13 + AstNode.right], 0
    add r13, 32
    add r12, 16
    mov eax, dword [r12 + Token.type]
    cmp eax, TOKEN_DELIMITER
    jne .loop
    add r12, 16
    jmp .loop

.parse_sub:
    mov dword [r13 + AstNode.type], AST_NODE_SUB
    jmp .build_decl

.parse_fn:
    mov dword [r13 + AstNode.type], AST_NODE_FUNC

.build_decl:
    mov eax, dword [r12 + Token.len]
    mov dword [r13 + AstNode.len], eax
    mov qword [r13 + AstNode.value], r12
    mov qword [r13 + AstNode.left], 0
    mov qword [r13 + AstNode.right], 0
    add r13, 32

    mov eax, dword [r12 + 48 + Token.type]
    cmp eax, TOKEN_DELIMITER
    jne .decl_no_args
    mov eax, dword [r12 + 64 + Token.type]
    cmp eax, TOKEN_DELIMITER
    jne .decl_no_args
    add r12, 80
    jmp .loop

.decl_no_args:
    add r12, 48
    jmp .loop

.handle_xmm:
    mov eax, dword [r12 + 16 + Token.type]
    cmp eax, TOKEN_OPERATOR
    jne .err_syntax

    mov eax, dword [r12 + 32 + Token.type]
    cmp eax, TOKEN_DELIMITER
    je .parse_xmm_load
    cmp eax, TOKEN_XMM
    je .parse_xmm_binop
    jmp .err_syntax

.parse_xmm_load:
    mov eax, dword [r12 + 48 + Token.type]
    cmp eax, TOKEN_REGISTER
    jne .err_syntax
    movzx r8, byte [r12 + 48 + Token.len]

    mov eax, dword [r12 + 64 + Token.type]
    cmp eax, TOKEN_DELIMITER
    je .xmm_load_nodisp
    cmp eax, TOKEN_OPERATOR
    je .xmm_load_disp
    jmp .err_syntax

.xmm_load_nodisp:
    mov dword [r13 + AstNode.type], AST_NODE_SIMD_LOAD
    movzx rax, byte [r12 + Token.len]
    mov qword [r13 + AstNode.left], rax
    mov qword [r13 + AstNode.right], r8
    mov qword [r13 + AstNode.value], 0
    add r13, 32
    add r12, 80
    jmp .loop

.xmm_load_disp:
    mov r9, qword [r12 + 64 + Token.ptr]
    cmp byte [r9], '+'
    jne .err_syntax

    push r8
    mov r8, qword [r12 + 80 + Token.ptr]
    mov edx, dword [r12 + 80 + Token.len]
    call parse_number_val
    mov r10, rax
    pop r8

    mov dword [r13 + AstNode.type], AST_NODE_SIMD_LOAD
    movzx rax, byte [r12 + Token.len]
    mov qword [r13 + AstNode.left], rax
    mov qword [r13 + AstNode.right], r8
    mov qword [r13 + AstNode.value], r10
    add r13, 32
    add r12, 112
    jmp .loop

.parse_xmm_binop:
    mov r8, qword [r12 + 48 + Token.ptr]
    xor eax, eax
    cmp byte [r8], '+'
    je .xmm_op_add
    cmp byte [r8], '-'
    je .xmm_op_sub
    cmp byte [r8], '*'
    je .xmm_op_mul
    cmp byte [r8], '^'
    je .xmm_op_xor
    jmp .err_syntax

.xmm_op_add:
    mov eax, OP_ADD
    jmp .xmm_binop_rhs
.xmm_op_sub:
    mov eax, OP_SUB
    jmp .xmm_binop_rhs
.xmm_op_mul:
    mov eax, OP_MUL
    jmp .xmm_binop_rhs
.xmm_op_xor:
    mov eax, OP_XOR

.xmm_binop_rhs:
    mov edx, dword [r12 + 64 + Token.type]
    cmp edx, TOKEN_XMM
    jne .err_syntax

    mov dword [r13 + AstNode.type], AST_NODE_SIMD_BINOP
    mov dword [r13 + AstNode.len], eax
    movzx r8, byte [r12 + Token.len]
    mov qword [r13 + AstNode.left], r8
    movzx r9, byte [r12 + 64 + Token.len]
    mov qword [r13 + AstNode.right], r9
    add r13, 32
    add r12, 80
    jmp .loop

.handle_delim_store:
    mov r8, qword [r12 + Token.ptr]

    cmp byte [r8], '{'
    je .handle_block_open

    cmp byte [r8], '}'
    je .handle_block_close

    cmp byte [r8], '['
    jne .err_syntax

    mov eax, dword [r12 + 16 + Token.type]
    cmp eax, TOKEN_REGISTER
    jne .err_syntax
    movzx r9, byte [r12 + 16 + Token.len]

    mov eax, dword [r12 + 32 + Token.type]
    cmp eax, TOKEN_DELIMITER
    je .hds_no_disp
    cmp eax, TOKEN_OPERATOR
    je .hds_with_disp
    jmp .err_syntax

.handle_block_open:
    add r12, 16
    jmp .loop

.handle_block_close:
    add r12, 16
    jmp .check_end_block

.hds_no_disp:
    xor r10, r10
    mov eax, dword [r12 + 48 + Token.type]
    cmp eax, TOKEN_OPERATOR
    jne .err_syntax

    mov eax, dword [r12 + 64 + Token.type]
    cmp eax, TOKEN_XMM
    je .hds_store_xmm_nodisp
    cmp eax, TOKEN_REGISTER
    je .hds_store_reg_nodisp
    cmp eax, TOKEN_NUMBER
    je .hds_store_num_nodisp
    jmp .err_syntax

.hds_store_xmm_nodisp:
    mov dword [r13 + AstNode.type], AST_NODE_SIMD_STORE
    mov qword [r13 + AstNode.left], r9
    movzx rax, byte [r12 + 64 + Token.len]
    mov qword [r13 + AstNode.right], rax
    mov qword [r13 + AstNode.value], 0
    add r13, 32
    add r12, 80
    jmp .loop

.hds_store_reg_nodisp:
    mov dword [r13 + AstNode.type], AST_NODE_STORE_REG
    mov dword [r13 + AstNode.len], 8
    mov qword [r13 + AstNode.left], r9
    movzx rax, byte [r12 + 64 + Token.len]
    mov qword [r13 + AstNode.right], rax
    mov qword [r13 + AstNode.value], 0
    add r13, 32
    add r12, 80
    jmp .loop

.hds_store_num_nodisp:
    push r9
    push r10
    mov r8, qword [r12 + 64 + Token.ptr]
    mov edx, dword [r12 + 64 + Token.len]
    call parse_number_val
    pop r10
    pop r9
    mov dword [r13 + AstNode.type], AST_NODE_STORE_MEM
    mov dword [r13 + AstNode.len], 8
    mov qword [r13 + AstNode.left], r9
    mov qword [r13 + AstNode.right], 0
    mov qword [r13 + AstNode.value], rax
    add r13, 32
    add r12, 80
    jmp .loop

.hds_with_disp:
    mov r8, qword [r12 + 32 + Token.ptr]
    cmp byte [r8], '+'
    jne .err_syntax

    mov eax, dword [r12 + 48 + Token.type]
    cmp eax, TOKEN_NUMBER
    jne .err_syntax

    push r9
    mov r8, qword [r12 + 48 + Token.ptr]
    mov edx, dword [r12 + 48 + Token.len]
    call parse_number_val
    mov r10, rax
    pop r9

    mov eax, dword [r12 + 64 + Token.type]
    cmp eax, TOKEN_DELIMITER
    jne .err_syntax
    mov eax, dword [r12 + 80 + Token.type]
    cmp eax, TOKEN_OPERATOR
    jne .err_syntax

    mov eax, dword [r12 + 96 + Token.type]
    cmp eax, TOKEN_XMM
    je .hds_store_xmm_disp
    cmp eax, TOKEN_REGISTER
    je .hds_store_reg_disp
    cmp eax, TOKEN_NUMBER
    je .hds_store_num_disp
    jmp .err_syntax

.hds_store_xmm_disp:
    mov dword [r13 + AstNode.type], AST_NODE_SIMD_STORE
    mov qword [r13 + AstNode.left], r9
    movzx rax, byte [r12 + 96 + Token.len]
    mov qword [r13 + AstNode.right], rax
    mov qword [r13 + AstNode.value], r10
    add r13, 32
    add r12, 112
    jmp .loop

.hds_store_reg_disp:
    mov dword [r13 + AstNode.type], AST_NODE_STORE_REG
    mov dword [r13 + AstNode.len], 8
    mov qword [r13 + AstNode.left], r9
    movzx rax, byte [r12 + 96 + Token.len]
    mov qword [r13 + AstNode.right], rax
    mov qword [r13 + AstNode.value], r10
    add r13, 32
    add r12, 112
    jmp .loop

.hds_store_num_disp:
    push r9
    push r10
    mov r8, qword [r12 + 96 + Token.ptr]
    mov edx, dword [r12 + 96 + Token.len]
    call parse_number_val
    pop r10
    pop r9
    pop rdx

    mov dword [r13 + AstNode.type], AST_NODE_STORE_MEM
    mov dword [r13 + AstNode.len], edx
    mov qword [r13 + AstNode.left], r9
    mov qword [r13 + AstNode.right], r10
    mov qword [r13 + AstNode.value], rax
    add r13, 32
    add r12, 112
    jmp .loop

.handle_reg:
    mov eax, dword [r12 + 16 + Token.type]
    cmp eax, TOKEN_OPERATOR
    jne .err_syntax

    mov eax, dword [r12 + 32 + Token.type]
    cmp eax, TOKEN_NUMBER
    je .reg_assign_num

    cmp eax, TOKEN_OPERATOR
    je .reg_assign_op

    cmp eax, TOKEN_DELIMITER
    je .reg_assign_delim

    cmp eax, TOKEN_REGISTER
    je .reg_assign_reg

    cmp eax, TOKEN_KEYWORD
    je .reg_assign_kw

    cmp eax, TOKEN_IDENTIFIER
    je .reg_assign_ident_or_inb
    jmp .err_syntax

.reg_assign_kw:
    mov r8, qword [r12 + 32 + Token.ptr]
    mov ecx, dword [r12 + 32 + Token.len]
    cmp ecx, 3
    jne .reg_assign_mem
    cmp byte [r8], 'n'
    jne .reg_assign_mem
    cmp byte [r8 + 1], 'e'
    jne .reg_assign_mem
    cmp byte [r8 + 2], 'w'
    jne .reg_assign_mem

    cmp byte [is_gc_enabled], 1
    jne .err_gc_needed

    mov eax, dword [r12 + 48 + Token.type]
    cmp eax, TOKEN_DELIMITER
    jne .err_syntax

    mov eax, dword [r12 + 64 + Token.type]
    cmp eax, TOKEN_NUMBER
    jne .err_syntax

    push r8
    mov r8, qword [r12 + 64 + Token.ptr]
    mov edx, dword [r12 + 64 + Token.len]
    call parse_number_val
    mov r9, rax
    pop r8

    mov eax, dword [r12 + 80 + Token.type]
    cmp eax, TOKEN_DELIMITER
    jne .err_syntax

    mov dword [r13 + AstNode.type], AST_NODE_GC_NEW
    movzx rax, byte [r12 + Token.len]
    mov qword [r13 + AstNode.left], rax
    mov qword [r13 + AstNode.value], r9
    add r13, 32
    add r12, 96
    jmp .loop

.reg_assign_mem:
    mov r8, qword [r12 + 32 + Token.ptr]
    mov ecx, dword [r12 + 32 + Token.len]
    mov edx, 8
    cmp ecx, 4
    jne .chk_load_dw
    cmp byte [r8], 'b'
    je .load_type_b
    cmp byte [r8], 'w'
    je .load_type_w
.chk_load_dw:
    cmp ecx, 5
    jne .do_parse_load
    cmp dword [r8], "dwor"
    je .load_type_d
    cmp dword [r8], "qwor"
    je .is_qword_assign
    jmp .do_parse_load

.is_qword_assign:
    mov edx, 8
    jmp .do_parse_load
.load_type_b:
    mov edx, 1
    jmp .do_parse_load
.load_type_w:
    mov edx, 2
    jmp .do_parse_load
.load_type_d:
    mov edx, 4

.do_parse_load:
    mov eax, dword [r12 + 48 + Token.type]
    cmp eax, TOKEN_DELIMITER
    jne .err_syntax
    mov eax, dword [r12 + 64 + Token.type]
    cmp eax, TOKEN_REGISTER
    jne .err_syntax
    movzx r9, byte [r12 + 64 + Token.len]

    mov eax, dword [r12 + 80 + Token.type]
    cmp eax, TOKEN_DELIMITER
    je .load_no_disp
    cmp eax, TOKEN_OPERATOR
    je .load_with_disp
    jmp .err_syntax

.load_no_disp:
    mov dword [r13 + AstNode.type], AST_NODE_LOAD_MEM
    mov dword [r13 + AstNode.len], edx
    movzx r8, byte [r12 + Token.len]
    mov qword [r13 + AstNode.left], r8
    mov qword [r13 + AstNode.right], r9
    mov qword [r13 + AstNode.value], 0
    add r13, 32
    add r12, 96
    jmp .loop

.load_with_disp:
    mov r8, qword [r12 + 80 + Token.ptr]
    cmp byte [r8], '+'
    jne .err_syntax

    mov eax, dword [r12 + 96 + Token.type]
    cmp eax, TOKEN_NUMBER
    jne .err_syntax

    push rdx
    push r9
    mov r8, qword [r12 + 96 + Token.ptr]
    mov edx, dword [r12 + 96 + Token.len]
    call parse_number_val
    mov r10, rax
    pop r9
    pop rdx

    mov eax, dword [r12 + 112 + Token.type]
    cmp eax, TOKEN_DELIMITER
    jne .err_syntax

    mov dword [r13 + AstNode.type], AST_NODE_LOAD_MEM
    mov dword [r13 + AstNode.len], edx
    movzx r8, byte [r12 + Token.len]
    mov qword [r13 + AstNode.left], r8
    mov qword [r13 + AstNode.right], r9
    mov qword [r13 + AstNode.value], r10
    add r13, 32
    add r12, 128
    jmp .loop

.reg_assign_op:
    mov r8, qword [r12 + 32 + Token.ptr]
    cmp byte [r8], '!'
    je .parse_logic_not
    jmp .err_syntax

.parse_logic_not:
    cmp byte [is_logic_mode], 1
    jne .err_logic_needed

    mov eax, dword [r12 + 48 + Token.type]
    cmp eax, TOKEN_REGISTER
    jne .err_syntax

    mov dword [r13 + AstNode.type], AST_NODE_LOGIC_NOT
    movzx rax, byte [r12 + Token.len]
    mov qword [r13 + AstNode.left], rax
    movzx rax, byte [r12 + 48 + Token.len]
    mov qword [r13 + AstNode.right], rax
    add r13, 32
    add r12, 64
    jmp .loop

.reg_assign_delim:
    mov r8, qword [r12 + 32 + Token.ptr]
    cmp byte [r8], '('
    je .parse_paren_expr
    cmp byte [r8], '['
    je .reg_assign_direct_mem
    jmp .err_syntax

.parse_paren_expr:
    cmp byte [is_logic_mode], 1
    jne .err_logic_needed

    mov eax, dword [r12 + 48 + Token.type]
    cmp eax, TOKEN_REGISTER
    jne .err_syntax
    movzx r8, byte [r12 + 48 + Token.len]

    mov eax, dword [r12 + 64 + Token.type]
    cmp eax, TOKEN_OPERATOR
    jne .err_syntax
    mov r9, qword [r12 + 64 + Token.ptr]

    xor edx, edx
    cmp byte [r9], '+'
    je .pop_add
    cmp byte [r9], '-'
    je .pop_sub
    cmp byte [r9], '*'
    je .pop_mul
    jmp .err_syntax

.pop_add:
    mov edx, OP_ADD
    jmp .pop_rhs
.pop_sub:
    mov edx, OP_SUB
    jmp .pop_rhs
.pop_mul:
    mov edx, OP_MUL

.pop_rhs:
    mov eax, dword [r12 + 80 + Token.type]
    cmp eax, TOKEN_REGISTER
    jne .err_syntax
    movzx r10, byte [r12 + 80 + Token.len]

    mov eax, dword [r12 + 96 + Token.type]
    cmp eax, TOKEN_DELIMITER
    jne .err_syntax
    mov r11, qword [r12 + 96 + Token.ptr]
    cmp byte [r11], ')'
    jne .err_syntax

    mov dword [r13 + AstNode.type], AST_NODE_PAREN_EXPR
    mov dword [r13 + AstNode.len], edx
    movzx rax, byte [r12 + Token.len]
    mov qword [r13 + AstNode.left], rax
    mov qword [r13 + AstNode.right], r8
    mov qword [r13 + AstNode.value], r10
    add r13, 32
    add r12, 112
    jmp .loop

.reg_assign_ident_or_inb:
    mov r8, qword [r12 + 32 + Token.ptr]
    mov ecx, dword [r12 + 32 + Token.len]
    cmp ecx, 3
    jne .reg_assign_var

    xor edx, edx
    cmp byte [r8], 'i'
    jne .reg_assign_var
    cmp byte [r8 + 1], 'n'
    jne .reg_assign_var
    cmp byte [r8 + 2], 'b'
    je .is_inb
    cmp byte [r8 + 2], 'w'
    je .is_inw
    jmp .reg_assign_var

.is_inb:
    mov edx, AST_NODE_INB
    jmp .parse_port_call
.is_inw:
    mov edx, AST_NODE_INW

.parse_port_call:
    mov eax, dword [r12 + 48 + Token.type]
    cmp eax, TOKEN_DELIMITER
    jne .err_syntax

    mov eax, dword [r12 + 64 + Token.type]
    cmp eax, TOKEN_NUMBER
    jne .err_syntax

    push rdx
    mov r8, qword [r12 + 64 + Token.ptr]
    mov edx, dword [r12 + 64 + Token.len]
    call parse_number_val
    mov r9, rax
    pop rdx

    mov eax, dword [r12 + 80 + Token.type]
    cmp eax, TOKEN_DELIMITER
    jne .err_syntax

    mov dword [r13 + AstNode.type], edx
    movzx rax, byte [r12 + Token.len]
    mov qword [r13 + AstNode.left], rax
    mov qword [r13 + AstNode.value], r9
    add r13, 32
    add r12, 96
    jmp .loop

.reg_assign_direct_mem:
    mov edx, 8
    mov eax, dword [r12 + 48 + Token.type]
    cmp eax, TOKEN_REGISTER
    jne .err_syntax
    movzx r9, byte [r12 + 48 + Token.len]

    mov eax, dword [r12 + 64 + Token.type]
    cmp eax, TOKEN_DELIMITER
    je .radm_no_disp
    cmp eax, TOKEN_OPERATOR
    je .radm_with_disp
    jmp .err_syntax

.radm_no_disp:
    mov dword [r13 + AstNode.type], AST_NODE_LOAD_MEM
    mov dword [r13 + AstNode.len], edx
    movzx r8, byte [r12 + Token.len]
    mov qword [r13 + AstNode.left], r8
    mov qword [r13 + AstNode.right], r9
    mov qword [r13 + AstNode.value], 0
    add r13, 32
    add r12, 80
    jmp .loop

.radm_with_disp:
    mov r8, qword [r12 + 64 + Token.ptr]
    cmp byte [r8], '+'
    jne .err_syntax

    mov eax, dword [r12 + 80 + Token.type]
    cmp eax, TOKEN_NUMBER
    jne .err_syntax

    push rdx
    push r9
    mov r8, qword [r12 + 80 + Token.ptr]
    mov edx, dword [r12 + 80 + Token.len]
    call parse_number_val
    mov r10, rax
    pop r9
    pop rdx

    mov eax, dword [r12 + 96 + Token.type]
    cmp eax, TOKEN_DELIMITER
    jne .err_syntax

    mov dword [r13 + AstNode.type], AST_NODE_LOAD_MEM
    mov dword [r13 + AstNode.len], edx
    movzx r8, byte [r12 + Token.len]
    mov qword [r13 + AstNode.left], r8
    mov qword [r13 + AstNode.right], r9
    mov qword [r13 + AstNode.value], r10
    add r13, 32
    add r12, 112
    jmp .loop

.reg_assign_var:
    mov r8, qword [r12 + 32 + Token.ptr]
    mov edx, dword [r12 + 32 + Token.len]
    call find_var
    test rax, rax
    jz .err_syntax

    mov r14, rax
    mov dword [r13 + AstNode.type], AST_NODE_REG_ASSIGN_VAR
    mov edx, dword [r14 + 24]
    mov dword [r13 + AstNode.len], edx
    movzx rdx, byte [r12 + Token.len]
    mov qword [r13 + AstNode.left], rdx
    mov rdx, qword [r14 + 16]
    mov qword [r13 + AstNode.right], rdx
    add r13, 32
    add r12, 48
    jmp .loop

.reg_assign_num:
    mov r8, qword [r12 + 32 + Token.ptr]
    mov edx, dword [r12 + 32 + Token.len]
    call parse_number_val

    mov dword [r13 + AstNode.type], AST_NODE_ASSIGN_IMM
    mov edx, dword [r12 + Token.len]
    mov dword [r13 + AstNode.len], edx
    mov qword [r13 + AstNode.value], rax
    mov qword [r13 + AstNode.left], 0
    mov qword [r13 + AstNode.right], 0
    add r13, 32
    add r12, 48
    jmp .loop

.reg_assign_reg:
    mov eax, dword [r12 + 48 + Token.type]
    cmp eax, TOKEN_OPERATOR
    je .parse_binop

    mov dword [r13 + AstNode.type], AST_NODE_ASSIGN_REG
    mov edx, dword [r12 + Token.len]
    mov dword [r13 + AstNode.len], edx
    movzx rax, byte [r12 + 32 + Token.len]
    mov qword [r13 + AstNode.value], rax
    mov qword [r13 + AstNode.left], 0
    mov qword [r13 + AstNode.right], 0
    add r13, 32
    add r12, 48
    jmp .loop

.parse_binop:
    mov r8, qword [r12 + 48 + Token.ptr]
    mov ecx, dword [r12 + 48 + Token.len]

    cmp ecx, 2
    je .check_binop2

    xor eax, eax
    cmp byte [r8], '+'
    je .op_add
    cmp byte [r8], '-'
    je .op_sub
    cmp byte [r8], '*'
    je .op_mul
    cmp byte [r8], '^'
    je .op_xor
    cmp byte [r8], '&'
    je .op_and
    jmp .err_syntax

.check_binop2:
    cmp word [r8], 0x3E3E
    je .op_shr
    cmp word [r8], 0x3C3C
    je .op_shl
    cmp word [r8], 0x2626
    je .op_logic_and
    cmp word [r8], 0x7C7C
    je .op_logic_or
    jmp .err_syntax

.op_logic_and:
    cmp byte [is_logic_mode], 1
    jne .err_logic_needed
    mov eax, dword [r12 + 64 + Token.type]
    cmp eax, TOKEN_REGISTER
    jne .err_syntax

    mov dword [r13 + AstNode.type], AST_NODE_LOGIC_AND
    movzx r8, byte [r12 + Token.len]
    mov qword [r13 + AstNode.left], r8
    movzx r9, byte [r12 + 32 + Token.len]
    mov qword [r13 + AstNode.right], r9
    movzx r10, byte [r12 + 64 + Token.len]
    mov qword [r13 + AstNode.value], r10
    add r13, 32
    add r12, 80
    jmp .loop

.op_logic_or:
    cmp byte [is_logic_mode], 1
    jne .err_logic_needed
    mov eax, dword [r12 + 64 + Token.type]
    cmp eax, TOKEN_REGISTER
    jne .err_syntax

    mov dword [r13 + AstNode.type], AST_NODE_LOGIC_OR
    movzx r8, byte [r12 + Token.len]
    mov qword [r13 + AstNode.left], r8
    movzx r9, byte [r12 + 32 + Token.len]
    mov qword [r13 + AstNode.right], r9
    movzx r10, byte [r12 + 64 + Token.len]
    mov qword [r13 + AstNode.value], r10
    add r13, 32
    add r12, 80
    jmp .loop

.op_add:
    mov eax, OP_ADD
    jmp .check_binop_rhs
.op_sub:
    mov eax, OP_SUB
    jmp .check_binop_rhs
.op_mul:
    mov eax, OP_MUL
    jmp .check_binop_rhs
.op_xor:
    mov eax, OP_XOR
    jmp .check_binop_rhs
.op_and:
    mov eax, OP_AND
    jmp .check_binop_rhs
.op_shr:
    mov eax, OP_SHR
    jmp .check_binop_rhs
.op_shl:
    mov eax, OP_SHL

.check_binop_rhs:
    mov edx, dword [r12 + 64 + Token.type]
    cmp edx, TOKEN_REGISTER
    je .binop_reg
    cmp edx, TOKEN_NUMBER
    je .binop_num
    jmp .err_syntax

.binop_reg:
    mov dword [r13 + AstNode.type], AST_NODE_BINOP_REG
    mov dword [r13 + AstNode.len], eax
    movzx r8, byte [r12 + Token.len]
    mov qword [r13 + AstNode.left], r8
    movzx r9, byte [r12 + 64 + Token.len]
    mov qword [r13 + AstNode.right], r9
    mov qword [r13 + AstNode.value], 0
    add r13, 32
    add r12, 80
    jmp .loop

.binop_num:
    push rax
    mov r8, qword [r12 + 64 + Token.ptr]
    mov edx, dword [r12 + 64 + Token.len]
    call parse_number_val
    mov r9, rax
    pop rax

    mov dword [r13 + AstNode.type], AST_NODE_BINOP_IMM
    mov dword [r13 + AstNode.len], eax
    movzx r8, byte [r12 + Token.len]
    mov qword [r13 + AstNode.left], r8
    mov qword [r13 + AstNode.value], r9
    mov qword [r13 + AstNode.right], 0
    add r13, 32
    add r12, 80
    jmp .loop

.handle_kw:
    mov r8, qword [r12 + Token.ptr]
    mov ecx, dword [r12 + Token.len]

    cmp ecx, 4
    jne .chk_pop
    cmp byte [r8], 'p'
    jne .chk_pop
    cmp byte [r8 + 1], 'u'
    jne .chk_pop
    cmp byte [r8 + 2], 's'
    jne .chk_pop
    cmp byte [r8 + 3], 'h'
    je .is_push

.chk_pop:
    cmp ecx, 3
    jne .check_enable
    cmp byte [r8], 'p'
    jne .check_enable
    cmp byte [r8 + 1], 'o'
    jne .check_enable
    cmp byte [r8 + 2], 'p'
    je .is_pop

.check_enable:
    cmp ecx, 6
    jne .check_call_kw
    cmp byte [r8], 'e'
    jne .check_call_kw
    cmp byte [r8 + 1], 'n'
    jne .check_call_kw
    cmp byte [r8 + 2], 'a'
    jne .check_call_kw
    cmp byte [r8 + 3], 'b'
    jne .check_call_kw
    cmp byte [r8 + 4], 'l'
    jne .check_call_kw
    cmp byte [r8 + 5], 'e'
    jne .check_call_kw

    mov eax, dword [r12 + 16 + Token.type]
    cmp eax, TOKEN_KEYWORD
    jne .err_syntax
    mov r9, qword [r12 + 16 + Token.ptr]
    mov ecx, dword [r12 + 16 + Token.len]

    cmp ecx, 2
    je .check_is_gc
    cmp ecx, 6
    je .check_is_blocks
    jmp .err_syntax

.is_push:
    mov eax, dword [r12 + 16 + Token.type]
    cmp eax, TOKEN_REGISTER
    jne .err_syntax

    mov dword [r13 + AstNode.type], AST_NODE_PUSH
    movzx rax, byte [r12 + 16 + Token.len]
    mov qword [r13 + AstNode.value], rax
    add r13, 32
    add r12, 32
    jmp .loop

.is_pop:
    mov eax, dword [r12 + 16 + Token.type]
    cmp eax, TOKEN_REGISTER
    jne .err_syntax

    mov dword [r13 + AstNode.type], AST_NODE_POP
    movzx rax, byte [r12 + 16 + Token.len]
    mov qword [r13 + AstNode.value], rax
    add r13, 32
    add r12, 32
    jmp .loop

.check_is_gc:
    cmp byte [r9], 'G'
    jne .err_syntax
    cmp byte [r9 + 1], 'C'
    jne .err_syntax
    mov byte [is_gc_enabled], 1
    mov dword [r13 + AstNode.type], AST_NODE_ENABLE_GC
    mov r14, gc_targets_table
    mov r15, gc_targets_count
    jmp .parse_enable_for

.check_is_blocks:
    cmp byte [r9], 'B'
    jne .err_syntax
    cmp byte [r9 + 1], 'L'
    jne .err_syntax
    cmp byte [r9 + 2], 'O'
    jne .err_syntax
    cmp byte [r9 + 3], 'C'
    jne .err_syntax
    cmp byte [r9 + 4], 'K'
    jne .err_syntax
    cmp byte [r9 + 5], 'S'
    jne .err_syntax
    mov byte [is_blocks_enabled], 1
    mov dword [r13 + AstNode.type], AST_NODE_ENABLE_BLOCKS
    mov r14, blocks_targets_table
    mov r15, blocks_targets_count

.parse_enable_for:
    mov eax, dword [r12 + 32 + Token.type]
    cmp eax, TOKEN_KEYWORD
    jne .err_syntax
    mov r10, qword [r12 + 32 + Token.ptr]
    cmp byte [r10], 'f'
    jne .err_syntax
    cmp byte [r10 + 1], 'o'
    jne .err_syntax
    cmp byte [r10 + 2], 'r'
    jne .err_syntax
    add r12, 48

    mov eax, dword [r12 + Token.type]
    cmp eax, TOKEN_DELIMITER
    jne .enable_target_loop
    mov r10, qword [r12 + Token.ptr]
    cmp byte [r10], ':'
    jne .enable_target_loop
    add r12, 16

.enable_target_loop:
    mov eax, dword [r12 + Token.type]
    cmp eax, TOKEN_IDENTIFIER
    je .check_if_decl
    cmp eax, TOKEN_DELIMITER
    je .skip_enable_delim
    jmp .enable_done

.check_if_decl:
    mov eax, dword [r12 + 16 + Token.type]
    cmp eax, TOKEN_OPERATOR
    jne .add_enable_target
    mov r9, qword [r12 + 16 + Token.ptr]
    cmp word [r9], 0x3A3A
    je .enable_done

.add_enable_target:
    mov rbx, [r15]
    shl rbx, 4
    mov r8, qword [r12 + Token.ptr]
    mov [r14 + rbx], r8
    mov r8d, dword [r12 + Token.len]
    mov dword [r14 + rbx + 8], r8d
    inc qword [r15]
    add r12, 16
    jmp .enable_target_loop

.skip_enable_delim:
    add r12, 16
    jmp .enable_target_loop

.enable_done:
    add r13, 32
    jmp .loop

.check_call_kw:
    cmp ecx, 4
    jne .check_mode_kw
    cmp byte [r8], 'c'
    jne .check_mode_kw
    cmp byte [r8 + 1], 'a'
    jne .check_mode_kw
    cmp byte [r8 + 2], 'l'
    jne .check_mode_kw
    cmp byte [r8 + 3], 'l'
    jne .check_mode_kw

    mov eax, dword [r12 + 16 + Token.type]
    cmp eax, TOKEN_KEYWORD
    jne .is_normal_call

    mov r9, qword [r12 + 16 + Token.ptr]
    mov ecx, dword [r12 + 16 + Token.len]
    cmp ecx, 8
    je .check_asm_call
    cmp ecx, 3
    je .check_hex_call
    cmp ecx, 1
    je .check_c_call
    jmp .is_normal_call

.check_asm_call:
    cmp byte [r9], 'a'
    jne .is_normal_call
    mov edx, AST_NODE_INLINE_ASM
    jmp .parse_inline_block

.check_hex_call:
    cmp byte [r9], 'h'
    jne .is_normal_call
    cmp byte [r9 + 1], 'e'
    jne .is_normal_call
    cmp byte [r9 + 2], 'x'
    jne .is_normal_call
    mov edx, AST_NODE_INLINE_HEX
    jmp .parse_inline_block

.check_c_call:
    cmp byte [r9], 'C'
    jne .is_normal_call
    mov edx, AST_NODE_INLINE_C

.parse_inline_block:
    mov r8, qword [r12 + 80 + Token.ptr]
    mov r9d, dword [r12 + 80 + Token.len]

    add r12, 144
    mov r10, qword [r12 + Token.ptr]

.find_eoi:
    mov eax, dword [r12 + Token.type]
    cmp eax, TOKEN_EOF
    je .err_syntax

    mov r11, qword [r12 + Token.ptr]
    mov ecx, dword [r12 + Token.len]
    cmp ecx, r9d
    jne .skip_inl

    push rdi
    push rsi
    push rcx
    mov rdi, r11
    mov rsi, r8
    repe cmpsb
    pop rcx
    pop rsi
    pop rdi
    je .found_eoi

.skip_inl:
    add r12, 16
    jmp .find_eoi

.found_eoi:
    mov dword [r13 + AstNode.type], edx
    mov qword [r13 + AstNode.left], r10
    mov rax, r11
    sub rax, r10
    mov qword [r13 + AstNode.right], rax
    add r13, 32
    add r12, 16
    jmp .loop

.is_normal_call:
    mov dword [r13 + AstNode.type], AST_NODE_CALL
    mov qword [r13 + AstNode.value], r12
    add r13, 32
    add r12, 32
    jmp .loop

.check_mode_kw:
    cmp ecx, 4
    jne .check_say
    cmp byte [r8], 'm'
    jne .check_say
    cmp byte [r8 + 1], 'o'
    jne .check_say
    cmp byte [r8 + 2], 'd'
    jne .check_say
    cmp byte [r8 + 3], 'e'
    jne .check_say

    mov eax, dword [r12 + 16 + Token.type]
    cmp eax, TOKEN_STRING
    jne .err_syntax

    mov r9, qword [r12 + 16 + Token.ptr]
    mov edx, dword [r12 + 16 + Token.len]

    cmp edx, 4
    jne .chk_m_kids
    cmp byte [r9], 'k'
    jne .chk_m_vars
    cmp byte [r9 + 1], 'i'
    jne .chk_m_vars
    cmp byte [r9 + 2], 'd'
    jne .chk_m_vars
    cmp byte [r9 + 3], 's'
    jne .chk_m_vars
    mov byte [is_kids_mode], 1
    add r12, 32
    jmp .loop

.chk_m_vars:
    cmp byte [r9], 'v'
    jne .err_syntax
    cmp byte [r9 + 1], 'a'
    jne .err_syntax
    cmp byte [r9 + 2], 'r'
    jne .err_syntax
    cmp byte [r9 + 3], 's'
    jne .err_syntax
    mov byte [is_vars_mode], 1
    add r12, 32
    jmp .loop

.chk_m_kids:
    cmp edx, 5
    jne .chk_m_sys
    cmp byte [r9], 'o'
    jne .chk_m_logic
    cmp byte [r9 + 1], 's'
    jne .chk_m_logic
    cmp byte [r9 + 2], 'd'
    jne .chk_m_logic
    cmp byte [r9 + 3], 'e'
    jne .chk_m_logic
    cmp byte [r9 + 4], 'v'
    jne .chk_m_logic
    mov byte [is_osdev_mode], 1
    add r12, 32
    jmp .loop

.chk_m_logic:
    cmp byte [r9], 'l'
    jne .err_syntax
    cmp byte [r9 + 1], 'o'
    jne .err_syntax
    cmp byte [r9 + 2], 'g'
    jne .err_syntax
    cmp byte [r9 + 3], 'i'
    jne .err_syntax
    cmp byte [r9 + 4], 'c'
    jne .err_syntax
    mov byte [is_logic_mode], 1
    add r12, 32
    jmp .loop

.chk_m_sys:
    cmp edx, 3
    jne .set_m_loser
    cmp byte [r9], 's'
    jne .set_m_loser
    cmp byte [r9 + 1], 'y'
    jne .set_m_loser
    cmp byte [r9 + 2], 's'
    jne .set_m_loser
    mov byte [is_sys_mode], 1
    add r12, 32
    jmp .loop

.set_m_loser:
    mov byte [is_loser_mode], 1
    add r12, 32
    jmp .loop

.check_say:
    cmp ecx, 3
    jne .check_repeat
    cmp byte [r8], 's'
    jne .check_repeat
    cmp byte [r8 + 1], 'a'
    jne .check_repeat
    cmp byte [r8 + 2], 'y'
    jne .check_repeat

    cmp byte [is_kids_mode], 1
    jne .err_kids_needed

    mov eax, dword [r12 + 16 + Token.type]
    cmp eax, TOKEN_STRING
    jne .err_syntax

    mov dword [r13 + AstNode.type], AST_NODE_SAY
    mov eax, dword [r12 + 16 + Token.len]
    mov dword [r13 + AstNode.len], eax
    mov r9, qword [r12 + 16 + Token.ptr]
    mov qword [r13 + AstNode.value], r9
    add r13, 32
    add r12, 32
    jmp .loop

.check_repeat:
    cmp ecx, 6
    jne .check_mut
    cmp byte [r8], 'r'
    jne .check_mut
    cmp byte [r8 + 1], 'e'
    jne .check_mut
    cmp byte [r8 + 2], 'p'
    jne .check_mut
    cmp byte [r8 + 3], 'e'
    jne .check_mut
    cmp byte [r8 + 4], 'a'
    jne .check_mut
    cmp byte [r8 + 5], 't'
    jne .check_mut

    cmp byte [is_kids_mode], 1
    jne .err_kids_needed

    mov eax, dword [r12 + 16 + Token.type]
    cmp eax, TOKEN_NUMBER
    jne .err_syntax

    push r8
    mov r8, qword [r12 + 16 + Token.ptr]
    mov edx, dword [r12 + 16 + Token.len]
    call parse_number_val
    mov r9, rax
    pop r8

    mov eax, dword [r12 + 32 + Token.type]
    cmp eax, TOKEN_KEYWORD
    je .rep_has_do
    cmp eax, TOKEN_DELIMITER
    je .rep_has_brace
    jmp .err_syntax

.rep_has_do:
    mov r10, qword [r12 + 32 + Token.ptr]
    cmp byte [r10], 'd'
    jne .err_syntax
    cmp byte [r10 + 1], 'o'
    jne .err_syntax
    mov eax, dword [r12 + 48 + Token.type]
    cmp eax, TOKEN_DELIMITER
    jne .rep_no_brace
    mov r10, qword [r12 + 48 + Token.ptr]
    cmp byte [r10], '{'
    jne .rep_no_brace
    add r12, 64
    jmp .emit_repeat

.rep_no_brace:
    add r12, 48
    jmp .emit_repeat

.rep_has_brace:
    mov r10, qword [r12 + 32 + Token.ptr]
    cmp byte [r10], '{'
    jne .err_syntax
    add r12, 48

.emit_repeat:
    mov dword [r13 + AstNode.type], AST_NODE_REPEAT
    mov qword [r13 + AstNode.value], r9
    mov qword [r13 + AstNode.left], 0

    mov rbx, [repeat_depth]
    mov [repeat_stack + rbx * 8], r13
    inc qword [repeat_depth]
    add r13, 32
    jmp .loop

.check_mut:
    cmp ecx, 3
    jne .check_print
    cmp byte [r8], 'm'
    jne .check_print
    cmp byte [r8 + 1], 'u'
    jne .check_print
    cmp byte [r8 + 2], 't'
    jne .check_print

    cmp byte [is_vars_mode], 1
    jne .err_vars_needed

    mov eax, dword [r12 + 16 + Token.type]
    cmp eax, TOKEN_IDENTIFIER
    jne .err_syntax

    mov eax, dword [r12 + 32 + Token.type]
    cmp eax, TOKEN_DELIMITER
    jne .err_syntax

    mov eax, dword [r12 + 48 + Token.type]
    cmp eax, TOKEN_KEYWORD
    jne .err_syntax

    mov r8, qword [r12 + 48 + Token.ptr]
    mov ecx, dword [r12 + 48 + Token.len]
    mov edx, 8
    cmp ecx, 4
    jne .chk_type_dw
    cmp byte [r8], 'b'
    je .type_b
    cmp byte [r8], 'w'
    je .type_w
.chk_type_dw:
    cmp ecx, 5
    jne .set_var_type
    cmp byte [r8], 'd'
    je .type_d
    jmp .set_var_type

.type_b:
    mov edx, 1
    jmp .set_var_type
.type_w:
    mov edx, 2
    jmp .set_var_type
.type_d:
    mov edx, 4

.set_var_type:
    add qword [curr_var_offset], 8
    mov rbx, [vars_count]
    shl rbx, 5
    mov r8, qword [r12 + 16 + Token.ptr]
    mov [vars_table + rbx], r8
    mov r8d, dword [r12 + 16 + Token.len]
    mov dword [vars_table + rbx + 8], r8d
    mov r8, [curr_var_offset]
    mov qword [vars_table + rbx + 16], r8
    mov dword [vars_table + rbx + 24], edx
    inc qword [vars_count]

    mov eax, dword [r12 + 64 + Token.type]
    cmp eax, TOKEN_OPERATOR
    jne .err_syntax

    mov eax, dword [r12 + 80 + Token.type]
    cmp eax, TOKEN_NUMBER
    je .mut_init_num
    cmp eax, TOKEN_REGISTER
    je .mut_init_reg
    jmp .err_syntax

.mut_init_num:
    push rdx
    mov r8, qword [r12 + 80 + Token.ptr]
    mov edx, dword [r12 + 80 + Token.len]
    call parse_number_val
    pop rdx

    mov dword [r13 + AstNode.type], AST_NODE_VAR_ASSIGN_IMM
    mov dword [r13 + AstNode.len], edx
    mov r8, [curr_var_offset]
    mov qword [r13 + AstNode.left], r8
    mov qword [r13 + AstNode.value], rax
    add r13, 32
    add r12, 96
    jmp .loop

.mut_init_reg:
    mov dword [r13 + AstNode.type], AST_NODE_VAR_ASSIGN_REG
    mov dword [r13 + AstNode.len], edx
    mov r8, [curr_var_offset]
    mov qword [r13 + AstNode.left], r8
    movzx r8, byte [r12 + 80 + Token.len]
    mov qword [r13 + AstNode.right], r8
    add r13, 32
    add r12, 96
    jmp .loop

.check_print:
    cmp ecx, 5
    jne .check_c_inline
    cmp byte [r8], 'p'
    jne .check_c_inline

    cmp byte [is_loser_mode], 1
    jne .err_loser_needed

    mov eax, dword [r12 + 16 + Token.type]
    cmp eax, TOKEN_STRING
    je .emit_print_node

    cmp eax, TOKEN_DELIMITER
    jne .err_syntax
    mov eax, dword [r12 + 32 + Token.type]
    cmp eax, TOKEN_STRING
    jne .err_syntax
    add r12, 16

.emit_print_node:
    mov dword [r13 + AstNode.type], AST_NODE_PRINT_STR
    mov eax, dword [r12 + 16 + Token.len]
    mov dword [r13 + AstNode.len], eax
    mov r9, qword [r12 + 16 + Token.ptr]
    mov qword [r13 + AstNode.value], r9
    add r13, 32
    add r12, 32
    mov eax, dword [r12 + Token.type]
    cmp eax, TOKEN_DELIMITER
    jne .loop
    add r12, 16
    jmp .loop

.check_c_inline:
    cmp ecx, 8
    jne .check_osdev_kw
    cmp byte [r8], 'c'
    jne .check_osdev_kw

    cmp byte [is_loser_mode], 1
    jne .err_loser_needed

.check_osdev_kw:
    cmp ecx, 3
    jne .check_outb

    cmp byte [r8], 'c'
    jne .chk_sti
    cmp byte [r8 + 1], 'l'
    jne .chk_sti
    cmp byte [r8 + 2], 'i'
    je .is_cli

.chk_sti:
    cmp byte [r8], 's'
    jne .chk_hlt
    cmp byte [r8 + 1], 't'
    jne .chk_hlt
    cmp byte [r8 + 2], 'i'
    je .is_sti

.chk_hlt:
    cmp byte [r8], 'h'
    jne .check_sys_kw
    cmp byte [r8 + 1], 'l'
    jne .check_sys_kw
    cmp byte [r8 + 2], 't'
    je .is_hlt
    jmp .check_sys_kw

.is_cli:
    cmp byte [is_osdev_mode], 1
    jne .err_osdev_needed
    mov dword [r13 + AstNode.type], AST_NODE_CLI
    add r13, 32
    add r12, 16
    jmp .loop

.is_sti:
    cmp byte [is_osdev_mode], 1
    jne .err_osdev_needed
    mov dword [r13 + AstNode.type], AST_NODE_STI
    add r13, 32
    add r12, 16
    jmp .loop

.is_hlt:
    cmp byte [is_osdev_mode], 1
    jne .err_osdev_needed
    mov dword [r13 + AstNode.type], AST_NODE_HLT
    add r13, 32
    add r12, 16
    jmp .loop

.check_outb:
    cmp ecx, 4
    jne .check_sys_kw
    cmp byte [r8], 'o'
    jne .check_sys_kw
    cmp byte [r8 + 1], 'u'
    jne .check_sys_kw
    cmp byte [r8 + 2], 't'
    jne .check_sys_kw
    cmp byte [r8 + 3], 'b'
    jne .check_sys_kw

    cmp byte [is_osdev_mode], 1
    jne .err_osdev_needed

    mov r8, qword [r12 + 32 + Token.ptr]
    mov edx, dword [r12 + 32 + Token.len]
    call parse_number_val
    push rax

    mov r8, qword [r12 + 64 + Token.ptr]
    mov edx, dword [r12 + 64 + Token.len]
    call parse_number_val
    mov r9, rax
    pop rax

    mov dword [r13 + AstNode.type], AST_NODE_OUTB
    mov qword [r13 + AstNode.left], rax
    mov qword [r13 + AstNode.right], r9
    add r13, 32
    add r12, 96
    jmp .loop

.check_sys_kw:
    cmp ecx, 3
    jne .check_syscall
    cmp byte [r8], 's'
    jne .check_cmp
    cmp byte [r8 + 1], 'y'
    jne .check_cmp
    cmp byte [r8 + 2], 's'
    jne .check_cmp

    cmp byte [is_sys_mode], 1
    jne .err_sys_needed

    mov r8, qword [r12 + 32 + Token.ptr]
    mov ecx, dword [r12 + 32 + Token.len]
    cmp ecx, 5
    je .parse_sys_write
    cmp ecx, 4
    je .parse_sys_read_or_exit
    jmp .err_syntax

.parse_sys_write:
    mov dword [r13 + AstNode.type], AST_NODE_SYS_WRITE
    jmp .parse_sys_3args

.parse_sys_read_or_exit:
    cmp byte [r8], 'r'
    je .parse_sys_read
    cmp byte [r8], 'e'
    je .parse_sys_exit
    jmp .err_syntax

.parse_sys_read:
    mov dword [r13 + AstNode.type], AST_NODE_SYS_READ
.parse_sys_3args:
    movzx r8, byte [r12 + 64 + Token.len]
    mov qword [r13 + AstNode.left], r8

    movzx r9, byte [r12 + 96 + Token.len]
    mov qword [r13 + AstNode.right], r9

    mov r8, qword [r12 + 128 + Token.ptr]
    mov edx, dword [r12 + 128 + Token.len]
    call parse_number_val
    mov qword [r13 + AstNode.value], rax
    add r13, 32
    add r12, 160
    jmp .loop

.parse_sys_exit:
    mov dword [r13 + AstNode.type], AST_NODE_SYS_EXIT
    mov eax, dword [r12 + 64 + Token.type]
    cmp eax, TOKEN_REGISTER
    je .pse_reg

    mov r8, qword [r12 + 64 + Token.ptr]
    mov edx, dword [r12 + 64 + Token.len]
    call parse_number_val
    mov qword [r13 + AstNode.value], rax
    mov qword [r13 + AstNode.left], 0
    add r13, 32
    add r12, 96
    jmp .loop

.pse_reg:
    movzx rax, byte [r12 + 64 + Token.len]
    mov qword [r13 + AstNode.left], 1
    mov qword [r13 + AstNode.right], rax
    mov qword [r13 + AstNode.value], 0
    add r13, 32
    add r12, 96
    jmp .loop

.check_syscall:
    cmp ecx, 7
    jne .check_cmp
    cmp byte [r8], 's'
    jne .check_cmp
    mov dword [r13 + AstNode.type], AST_NODE_SYSCALL
    add r13, 32
    add r12, 16
    jmp .loop

.check_cmp:
    cmp ecx, 3
    jne .check_jumps
    cmp byte [r8], 'c'
    jne .check_jumps
    cmp byte [r8 + 1], 'm'
    jne .check_jumps
    cmp byte [r8 + 2], 'p'
    jne .check_jumps

    mov eax, dword [r12 + 16 + Token.type]
    cmp eax, TOKEN_REGISTER
    jne .err_syntax

    mov edx, dword [r12 + 48 + Token.type]
    cmp edx, TOKEN_REGISTER
    je .cmp_reg
    cmp edx, TOKEN_NUMBER
    je .cmp_num
    jmp .err_syntax

.cmp_reg:
    mov dword [r13 + AstNode.type], AST_NODE_CMP_REG
    movzx r9, byte [r12 + 16 + Token.len]
    mov qword [r13 + AstNode.left], r9
    movzx r10, byte [r12 + 48 + Token.len]
    mov qword [r13 + AstNode.right], r10
    add r13, 32
    add r12, 64
    jmp .loop

.cmp_num:
    mov r8, qword [r12 + 48 + Token.ptr]
    mov edx, dword [r12 + 48 + Token.len]
    call parse_number_val

    mov dword [r13 + AstNode.type], AST_NODE_CMP_IMM
    movzx r9, byte [r12 + 16 + Token.len]
    mov qword [r13 + AstNode.left], r9
    mov qword [r13 + AstNode.value], rax
    add r13, 32
    add r12, 64
    jmp .loop

.check_jumps:
    cmp ecx, 3
    je .check_j3
    cmp ecx, 2
    je .check_j2
    jmp .check_end

.check_j3:
    cmp byte [r8], 'j'
    jne .check_end
    cmp byte [r8 + 1], 'm'
    jne .chk_jne
    cmp byte [r8 + 2], 'p'
    je .is_jmp
    jmp .check_end
.chk_jne:
    cmp byte [r8 + 1], 'n'
    jne .chk_jae
    cmp byte [r8 + 2], 'e'
    je .is_jne
    jmp .check_end
.chk_jae:
    cmp byte [r8 + 1], 'a'
    jne .chk_jle
    cmp byte [r8 + 2], 'e'
    je .is_jae
    jmp .check_end
.chk_jle:
    cmp byte [r8 + 1], 'l'
    jne .chk_jge
    cmp byte [r8 + 2], 'e'
    je .is_jle
    jmp .check_end
.chk_jge:
    cmp byte [r8 + 1], 'g'
    jne .chk_jbe
    cmp byte [r8 + 2], 'e'
    je .is_jge
    jmp .check_end
.chk_jbe:
    cmp byte [r8 + 1], 'b'
    jne .check_end
    cmp byte [r8 + 2], 'e'
    je .is_jbe
    jmp .check_end

.check_j2:
    cmp byte [r8], 'j'
    jne .check_end
    cmp byte [r8 + 1], 'e'
    je .is_je
    cmp byte [r8 + 1], 'b'
    je .is_jb
    cmp byte [r8 + 1], 'l'
    je .is_jl
    cmp byte [r8 + 1], 'g'
    je .is_jg
    cmp byte [r8 + 1], 'a'
    je .is_ja
    jmp .check_end

.is_jmp:
    mov eax, AST_NODE_JMP
    jmp .emit_jump_node
.is_jne:
    mov eax, AST_NODE_JNE
    jmp .emit_jump_node
.is_jae:
    mov eax, AST_NODE_JAE
    jmp .emit_jump_node
.is_jle:
    mov eax, AST_NODE_JLE
    jmp .emit_jump_node
.is_jge:
    mov eax, AST_NODE_JGE
    jmp .emit_jump_node
.is_jbe:
    mov eax, AST_NODE_JBE
    jmp .emit_jump_node
.is_je:
    mov eax, AST_NODE_JE
    jmp .emit_jump_node
.is_jb:
    mov eax, AST_NODE_JB
    jmp .emit_jump_node
.is_jl:
    mov eax, AST_NODE_JL
    jmp .emit_jump_node
.is_jg:
    mov eax, AST_NODE_JG
    jmp .emit_jump_node
.is_ja:
    mov eax, AST_NODE_JA

.emit_jump_node:
    mov dword [r13 + AstNode.type], eax
    mov qword [r13 + AstNode.value], r12
    add r13, 32
    add r12, 32
    jmp .loop

.check_end:
    cmp ecx, 3
    jne .check_mem_types
    cmp byte [r8], 'e'
    jne .check_mem_types
    cmp byte [r8 + 1], 'n'
    jne .check_mem_types
    cmp byte [r8 + 2], 'd'
    jne .check_mem_types
    add r12, 16
    jmp .check_end_block

.check_end_block:
    mov rbx, [repeat_depth]
    test rbx, rbx
    jz .emit_fn_return

    dec qword [repeat_depth]
    mov rbx, [repeat_depth]
    mov r14, [repeat_stack + rbx * 8]

    mov dword [r13 + AstNode.type], AST_NODE_REPEAT_END
    mov qword [r13 + AstNode.left], r14
    add r13, 32
    jmp .loop

.emit_fn_return:
    mov dword [r13 + AstNode.type], AST_NODE_RETURN
    mov dword [r13 + AstNode.len], 3
    mov qword [r13 + AstNode.value], r12
    mov qword [r13 + AstNode.left], 0
    mov qword [r13 + AstNode.right], 0
    add r13, 32
    jmp .loop

.check_mem_types:
    xor edx, edx
    cmp ecx, 4
    jne .check_dw_qw
    cmp byte [r8], 'b'
    je .is_byte
    cmp byte [r8], 'w'
    je .is_word
    jmp .err_syntax

.check_dw_qw:
    cmp ecx, 5
    jne .err_syntax
    cmp byte [r8], 'd'
    je .is_dword
    cmp byte [r8], 'q'
    je .is_qword
    jmp .err_syntax

.is_byte:
    mov edx, 1
    jmp .parse_mem_store
.is_word:
    mov edx, 2
    jmp .parse_mem_store
.is_dword:
    mov edx, 4
    jmp .parse_mem_store
.is_qword:
    mov edx, 8

.parse_mem_store:
    mov eax, dword [r12 + 16 + Token.type]
    cmp eax, TOKEN_DELIMITER
    jne .err_syntax
    mov eax, dword [r12 + 32 + Token.type]
    cmp eax, TOKEN_REGISTER
    jne .err_syntax
    movzx r9, byte [r12 + 32 + Token.len]

    mov eax, dword [r12 + 48 + Token.type]
    cmp eax, TOKEN_DELIMITER
    je .pms_no_disp
    cmp eax, TOKEN_OPERATOR
    je .pms_with_disp
    jmp .err_syntax

.pms_no_disp:
    xor r10, r10
    mov eax, dword [r12 + 64 + Token.type]
    cmp eax, TOKEN_OPERATOR
    jne .err_syntax

    mov eax, dword [r12 + 80 + Token.type]
    cmp eax, TOKEN_XMM
    je .store_from_xmm_nodisp
    cmp eax, TOKEN_REGISTER
    je .store_from_reg_nodisp
    cmp eax, TOKEN_NUMBER
    je .store_from_num_nodisp
    jmp .err_syntax

.store_from_xmm_nodisp:
    mov dword [r13 + AstNode.type], AST_NODE_SIMD_STORE
    mov qword [r13 + AstNode.left], r9
    movzx rax, byte [r12 + 80 + Token.len]
    mov qword [r13 + AstNode.right], rax
    mov qword [r13 + AstNode.value], 0
    add r13, 32
    add r12, 96
    jmp .loop

.store_from_num_nodisp:
    push rdx
    push r9
    push r10
    mov r8, qword [r12 + 80 + Token.ptr]
    mov edx, dword [r12 + 80 + Token.len]
    call parse_number_val
    pop r10
    pop r9
    pop rdx

    mov dword [r13 + AstNode.type], AST_NODE_STORE_MEM
    mov dword [r13 + AstNode.len], edx
    mov qword [r13 + AstNode.left], r9
    mov qword [r13 + AstNode.right], 0
    mov qword [r13 + AstNode.value], rax
    add r13, 32
    add r12, 96
    jmp .loop

.store_from_reg_nodisp:
    mov dword [r13 + AstNode.type], AST_NODE_STORE_REG
    mov dword [r13 + AstNode.len], edx
    mov qword [r13 + AstNode.left], r9
    movzx rax, byte [r12 + 80 + Token.len]
    mov qword [r13 + AstNode.right], rax
    mov qword [r13 + AstNode.value], 0
    add r13, 32
    add r12, 96
    jmp .loop

.pms_with_disp:
    mov r8, qword [r12 + 48 + Token.ptr]
    cmp byte [r8], '+'
    jne .err_syntax

    mov eax, dword [r12 + 64 + Token.type]
    cmp eax, TOKEN_NUMBER
    jne .err_syntax

    push rdx
    push r9
    mov r8, qword [r12 + 64 + Token.ptr]
    mov edx, dword [r12 + 64 + Token.len]
    call parse_number_val
    mov r10, rax
    pop r9
    pop rdx

    mov eax, dword [r12 + 80 + Token.type]
    cmp eax, TOKEN_DELIMITER
    jne .err_syntax
    mov eax, dword [r12 + 96 + Token.type]
    cmp eax, TOKEN_OPERATOR
    jne .err_syntax

    mov eax, dword [r12 + 112 + Token.type]
    cmp eax, TOKEN_XMM
    je .store_from_xmm_disp
    cmp eax, TOKEN_REGISTER
    je .store_from_reg_disp
    cmp eax, TOKEN_NUMBER
    je .store_from_num_disp
    jmp .err_syntax

.store_from_xmm_disp:
    mov dword [r13 + AstNode.type], AST_NODE_SIMD_STORE
    mov qword [r13 + AstNode.left], r9
    movzx rax, byte [r12 + 112 + Token.len]
    mov qword [r13 + AstNode.right], rax
    mov qword [r13 + AstNode.value], r10
    add r13, 32
    add r12, 128
    jmp .loop

.store_from_reg_disp:
    mov dword [r13 + AstNode.type], AST_NODE_STORE_REG
    mov dword [r13 + AstNode.len], edx
    mov qword [r13 + AstNode.left], r9
    movzx rax, byte [r12 + 112 + Token.len]
    mov qword [r13 + AstNode.right], rax
    mov qword [r13 + AstNode.value], r10
    add r13, 32
    add r12, 128
    jmp .loop

.store_from_num_disp:
    push rdx
    push r9
    push r10
    mov r8, qword [r12 + 112 + Token.ptr]
    mov edx, dword [r12 + 112 + Token.len]
    call parse_number_val
    pop r10
    pop r9
    pop rdx

    mov dword [r13 + AstNode.type], AST_NODE_STORE_MEM
    mov dword [r13 + AstNode.len], edx
    mov qword [r13 + AstNode.left], r9
    mov qword [r13 + AstNode.right], r10
    mov qword [r13 + AstNode.value], rax
    add r13, 32
    add r12, 128
    jmp .loop

.done:
    mov rax, r13
    sub rax, rdi
    shr rax, 5
    pop rbp
    ret

.err_loser_needed:
    mov rax, -1
    mov rdx, qword [r12 + Token.ptr]
    pop rbp
    ret

.err_syntax:
    mov rax, -2
    mov rdx, qword [r12 + Token.ptr]
    pop rbp
    ret

.err_osdev_needed:
    mov rax, -3
    mov rdx, qword [r12 + Token.ptr]
    pop rbp
    ret

.err_sys_needed:
    mov rax, -4
    mov rdx, qword [r12 + Token.ptr]
    pop rbp
    ret

.err_vars_needed:
    mov rax, -5
    mov rdx, qword [r12 + Token.ptr]
    pop rbp
    ret

.err_logic_needed:
    mov rax, -6
    mov rdx, qword [r12 + Token.ptr]
    pop rbp
    ret

.err_gc_needed:
    mov rax, -7
    mov rdx, qword [r12 + Token.ptr]
    pop rbp
    ret

.err_kids_needed:
    mov rax, -8
    mov rdx, qword [r12 + Token.ptr]
    pop rbp
    ret