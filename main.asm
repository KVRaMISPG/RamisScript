format ELF64 executable 3
entry _start

SYS_READ    = 0
SYS_WRITE   = 1
SYS_OPEN    = 2
SYS_CLOSE   = 3
SYS_MMAP    = 9
SYS_EXIT    = 60

PROT_RWX    = 7
MAP_ANON_PR = 022h
O_RDONLY    = 0
O_CREAT_WR  = 0241h
MODE_EXEC   = 0755o

segment readable executable

include 'include/tokens.inc'
include 'include/ast.inc'
include 'core/lexer.asm'
include 'core/parser.asm'
include 'core/codegen.asm'
include 'core/error.asm'

_start:
    pop r15
    cmp r15, 2
    jl .err_usage

    pop rsi
    dec r15

.parse_args_loop:
    cmp r15, 0
    je .compile_start
    pop rdi

    mov eax, dword [rdi]
    cmp eax, "help"
    je .cmd_help
    cmp eax, "vers"
    jne .check_info
    cmp dword [rdi + 3], "sion"
    je .cmd_version

.check_info:
    cmp eax, "info"
    je .cmd_info
    cmp eax, "--ru"
    je .set_lang_ru
    cmp dword [rdi], "-jit" 
    je .set_jit
    cmp dword [rdi], "-rse"
    je .set_rse
    cmp dword [rdi], "-run"
    je .set_run

    cmp qword [src_filename], 0
    je .set_src
    cmp qword [out_filename], 0
    je .set_out
    jmp .next_arg

.set_lang_ru:
    mov byte [lang_ru], 1
    jmp .next_arg
.set_jit:
    mov byte [is_jit_mode], 1
    jmp .next_arg
.set_rse:
    mov byte [is_rse_mode], 1
    jmp .next_arg
.set_run:
    mov byte [is_run_mode], 1
    jmp .next_arg
.set_src:
    mov [src_filename], rdi
    jmp .next_arg
.set_out:
    mov [out_filename], rdi

.next_arg:
    dec r15
    jmp .parse_args_loop

.cmd_help:
    cmp byte [lang_ru], 1
    je .help_ru
    mov rsi, msg_help_en
    mov rdx, msg_help_en_len
    jmp .print_exit
.help_ru:
    mov rsi, msg_help_ru
    mov rdx, msg_help_ru_len
    jmp .print_exit

.cmd_version:
    mov rsi, msg_version
    mov rdx, msg_version_len
    jmp .print_exit

.cmd_info:
    cmp byte [lang_ru], 1
    je .info_ru
    mov rsi, msg_info_en
    mov rdx, msg_info_en_len
    jmp .print_exit
.info_ru:
    mov rsi, msg_info_ru
    mov rdx, msg_info_ru_len
    jmp .print_exit

.compile_start:
    cmp qword [src_filename], 0
    je .err_usage

    cmp byte [is_run_mode], 1
    je .run_rse_file

    cmp qword [out_filename], 0
    jne .read_src
    
    cmp byte [is_rse_mode], 1
    je .set_default_rse
    mov qword [out_filename], default_out
    jmp .read_src

.set_default_rse:
    mov qword [out_filename], default_out_rse

.read_src:
    mov rax, SYS_OPEN
    mov rdi, [src_filename]
    mov rsi, O_RDONLY
    xor rdx, rdx
    syscall
    test rax, rax
    js .err_open
    mov [src_fd], rax

    mov rax, SYS_READ
    mov rdi, [src_fd]
    mov rsi, src_buf
    mov rdx, 1048576
    syscall
    test rax, rax
    js .err_read
    mov byte [src_buf + rax], 0

    mov rax, SYS_CLOSE
    mov rdi, [src_fd]
    syscall

.compile:
    mov rsi, src_buf
    mov rdi, tokens_buf
    call tokenize

    mov rsi, tokens_buf
    mov rdi, ast_buf
    call parse_program

    cmp rax, 0
    jl .handle_compile_error

    mov rcx, rax
    mov rsi, ast_buf
    mov rdi, code_buf
    call generate_code
    mov [code_size], rax

    cmp qword [code_size], 0
    jle .empty_code_exit

    cmp byte [is_jit_mode], 1
    je .run_jit
    
    cmp byte [is_rse_mode], 1
    je .write_rse

.write_out:
    mov rax, [code_size]
    add rax, 120
    mov [elf_filesz], rax
    mov qword [elf_memsz], 0x2000000

    mov rax, SYS_OPEN
    mov rdi, [out_filename]
    mov rsi, O_CREAT_WR
    mov rdx, MODE_EXEC
    syscall
    test rax, rax
    js .err_write
    mov [out_fd], rax

    mov rax, SYS_WRITE
    mov rdi, [out_fd]
    mov rsi, elf64_header
    mov rdx, 120
    syscall

    mov rax, SYS_WRITE
    mov rdi, [out_fd]
    mov rsi, code_buf
    mov rdx, [code_size]
    syscall

    mov rax, SYS_CLOSE
    mov rdi, [out_fd]
    syscall

    cmp byte [lang_ru], 1
    je .ok_ru
    mov rsi, msg_ok_en
    mov rdx, msg_ok_en_len
    jmp .print_ok
.ok_ru:
    mov rsi, msg_ok_ru
    mov rdx, msg_ok_ru_len
.print_ok:
    mov rax, SYS_WRITE
    mov rdi, 1
    syscall
    xor rdi, rdi
    mov rax, SYS_EXIT
    syscall

.write_rse:
    mov rax, [code_size]
    mov [rse_header_size], rax
    
    mov rax, SYS_OPEN
    mov rdi, [out_filename]
    mov rsi, O_CREAT_WR
    mov rdx, MODE_EXEC
    syscall
    test rax, rax
    js .err_write
    mov [out_fd], rax

    mov rax, SYS_WRITE
    mov rdi, [out_fd]
    mov rsi, rse_header
    mov rdx, 32
    syscall

    mov rax, SYS_WRITE
    mov rdi, [out_fd]
    mov rsi, code_buf
    mov rdx, [code_size]
    syscall

    mov rax, SYS_CLOSE
    mov rdi, [out_fd]
    syscall

    cmp byte [lang_ru], 1
    je .ok_rse_ru
    mov rsi, msg_ok_rse_en
    mov rdx, msg_ok_rse_en_len
    jmp .print_ok
.ok_rse_ru:
    mov rsi, msg_ok_rse_ru
    mov rdx, msg_ok_rse_ru_len
    jmp .print_ok

.run_jit:
    mov rax, SYS_MMAP
    xor rdi, rdi
    mov rsi, 1048576
    mov rdx, PROT_RWX
    mov r10, MAP_ANON_PR
    xor r8, r8
    xor r9, r9
    syscall
    test rax, rax
    js .err_jit
    mov [exec_mem], rax

    mov rsi, code_buf
    mov rdi, [exec_mem]
    mov rcx, [code_size]
    rep movsb

    mov rax, [exec_mem]
    call rax

    mov rdi, rax
    mov rax, SYS_EXIT
    syscall

.run_rse_file:
    mov rax, SYS_OPEN
    mov rdi, [src_filename]
    mov rsi, O_RDONLY
    xor rdx, rdx
    syscall
    test rax, rax
    js .err_open
    mov [src_fd], rax

    mov rax, SYS_READ
    mov rdi, [src_fd]
    mov rsi, src_buf
    mov rdx, 1048576
    syscall
    test rax, rax
    js .err_read
    
    mov rax, SYS_CLOSE
    mov rdi, [src_fd]
    syscall

    cmp dword [src_buf], 0x01455352
    jne .err_format

    mov rax, qword [src_buf + 16]
    mov [code_size], rax

    mov rax, SYS_MMAP
    xor rdi, rdi
    mov rsi, 1048576
    mov rdx, PROT_RWX
    mov r10, MAP_ANON_PR
    xor r8, r8
    xor r9, r9
    syscall
    test rax, rax
    js .err_jit
    mov [exec_mem], rax

    mov rsi, src_buf
    add rsi, 32
    mov rdi, [exec_mem]
    mov rcx, [code_size]
    rep movsb

    mov rax, [exec_mem]
    call rax

    mov rdi, rax
    mov rax, SYS_EXIT
    syscall

.empty_code_exit:
    xor rdi, rdi
    mov rax, SYS_EXIT
    syscall

.handle_compile_error:
    mov rdi, rdx
    mov rsi, rax
    call report_error
    mov rdi, 1
    mov rax, SYS_EXIT
    syscall

.err_usage:
    cmp byte [lang_ru], 1
    je .usage_ru
    mov rsi, msg_usage_en
    mov rdx, msg_usage_en_len
    jmp .print_err
.usage_ru:
    mov rsi, msg_usage_ru
    mov rdx, msg_usage_ru_len
    jmp .print_err

.err_open:
    mov rsi, msg_err_open
    mov rdx, msg_err_open_len
    jmp .print_err
.err_read:
    mov rsi, msg_err_read
    mov rdx, msg_err_read_len
    jmp .print_err
.err_write:
    mov rsi, msg_err_write
    mov rdx, msg_err_write_len
    jmp .print_err
.err_jit:
    mov rsi, msg_err_jit
    mov rdx, msg_err_jit_len
    jmp .print_err
.err_format:
    mov rsi, msg_err_fmt
    mov rdx, msg_err_fmt_len

.print_err:
    mov rax, SYS_WRITE
    mov rdi, 2
    syscall
    mov rdi, 1
    mov rax, SYS_EXIT
    syscall

.print_exit:
    mov rax, SYS_WRITE
    mov rdi, 1
    syscall
    xor rdi, rdi
    mov rax, SYS_EXIT
    syscall

segment readable writeable

align 8
elf64_header:
    db 0x7F, "ELF", 2, 1, 1, 0
    times 8 db 0
    dw 2
    dw 0x3E
    dd 1
    dq 0x400078
    dq 64
    dq 0
    dd 0
    dw 64
    dw 56
    dw 1
    dw 0
    dw 0
    dw 0

    dd 1
    dd 7
    dq 0
    dq 0x400000
    dq 0x400000
elf_filesz:
    dq 120
elf_memsz:
    dq 0x2000000
    dq 0x1000

align 8
rse_header:
    db "RSE", 0x01
    dd 0
    dq 0
rse_header_size:
    dq 0
    dq 0

msg_usage_en:       db "Usage: ramisc [options] <source.rsmc> [output_binary]", 0Ah
msg_usage_en_len    = $ - msg_usage_en
msg_help_en:        db "RamisScript Baremetal Compiler", 0Ah, "Compiles .rsmc directly into native ELF64 standalone executables.", 0Ah
msg_help_en_len     = $ - msg_help_en
msg_info_en:        db "RamisScript - The educational zero-overhead programming language.", 0Ah
msg_info_en_len     = $ - msg_info_en
msg_ok_en:          db "Native ELF64 binary generated.", 0Ah
msg_ok_en_len       = $ - msg_ok_en
msg_ok_rse_en:      db "Native RSE binary generated.", 0Ah
msg_ok_rse_en_len   = $ - msg_ok_rse_en

msg_usage_ru:       db "Использование: ramisc [опции] <source.rsmc> [output_binary]", 0Ah
msg_usage_ru_len    = $ - msg_usage_ru
msg_help_ru:        db "Baremetal-компилятор RamisScript", 0Ah, "Компилирует файлы .rsmc в нативные исполняемые ELF64-бинарники.", 0Ah
msg_help_ru_len     = $ - msg_help_ru
msg_info_ru:        db "RamisScript - Образовательный язык программирования с нулевым оверхедом.", 0Ah
msg_info_ru_len     = $ - msg_info_ru
msg_ok_ru:          db "Исполняемый ELF64 бинарник успешно создан.", 0Ah
msg_ok_ru_len       = $ - msg_ok_ru
msg_ok_rse_ru:      db "Исполняемый RSE бинарник успешно создан.", 0Ah
msg_ok_rse_ru_len   = $ - msg_ok_rse_ru

msg_version:        db "RamisScript Compiler v0.7.0 (Monster Hybrid Edition)", 0Ah, "(c) 2026 KV/RaMIS Project Group", 0Ah
msg_version_len     = $ - msg_version

msg_err_open:       db "Error: Cannot open source file", 0Ah
msg_err_open_len    = $ - msg_err_open
msg_err_read:       db "Error: Failed to read source file", 0Ah
msg_err_read_len    = $ - msg_err_read
msg_err_write:      db "Error: Cannot write output binary", 0Ah
msg_err_write_len   = $ - msg_err_write
msg_err_jit:        db "Error: JIT memory allocation failed", 0Ah
msg_err_jit_len     = $ - msg_err_jit
msg_err_fmt:        db "Error: Invalid RSE executable format", 0Ah
msg_err_fmt_len     = $ - msg_err_fmt

msg_err_loser_en:   db 0Ah, "[-] Compilation Error: High-level syntax requires declaring you are a loser:", 0Ah, '    mode "yeah, i am a loser"', 0Ah, 0Ah
msg_err_loser_en_len = $ - msg_err_loser_en
msg_err_loser_ru:   db 0Ah, "[-] Ошибка компиляции: Требуется объявить высокоуровневый режим:", 0Ah, '    mode "yeah, i am a loser"', 0Ah, 0Ah
msg_err_loser_ru_len = $ - msg_err_loser_ru

msg_err_osdev_en:   db 0Ah, "[-] Compilation Error: Hardware instructions require OS-Dev mode:", 0Ah, '    mode "osdev"', 0Ah, 0Ah
msg_err_osdev_en_len = $ - msg_err_osdev_en
msg_err_osdev_ru:   db 0Ah, "[-] Ошибка компиляции: Аппаратные инструкции требуют режима OS-Dev:", 0Ah, '    mode "osdev"', 0Ah, 0Ah
msg_err_osdev_ru_len = $ - msg_err_osdev_ru

msg_err_sys_en:     db 0Ah, "[-] Compilation Error: System macros require Sys mode:", 0Ah, '    mode "sys"', 0Ah, 0Ah
msg_err_sys_en_len  = $ - msg_err_sys_en
msg_err_sys_ru:     db 0Ah, "[-] Ошибка компиляции: Системные макросы требуют режима Sys:", 0Ah, '    mode "sys"', 0Ah, 0Ah
msg_err_sys_ru_len  = $ - msg_err_sys_ru

msg_err_vars_en:    db 0Ah, "[-] Compilation Error: Local variables require Vars mode:", 0Ah, '    mode "vars"', 0Ah, 0Ah
msg_err_vars_en_len = $ - msg_err_vars_en
msg_err_vars_ru:    db 0Ah, "[-] Ошибка компиляции: Локальные переменные требуют режима Vars:", 0Ah, '    mode "vars"', 0Ah, 0Ah
msg_err_vars_ru_len = $ - msg_err_vars_ru

msg_err_logic_en:   db 0Ah, "[-] Compilation Error: Logical operators and parentheses require Logic mode:", 0Ah, '    mode "logic"', 0Ah, 0Ah
msg_err_logic_en_len = $ - msg_err_logic_en
msg_err_logic_ru:   db 0Ah, "[-] Ошибка компиляции: Логические операторы и скобки требуют режима Logic:", 0Ah, '    mode "logic"', 0Ah, 0Ah
msg_err_logic_ru_len = $ - msg_err_logic_ru

msg_err_gc_en:      db 0Ah, "[-] Compilation Error: Dynamic GC allocation requires enabling GC for target types:", 0Ah, '    enable GC: <TypeA>, <TypeB>', 0Ah, 0Ah
msg_err_gc_en_len   = $ - msg_err_gc_en
msg_err_gc_ru:      db 0Ah, "[-] Ошибка компиляции: Аллокация с GC требует включения сборщика для типов:", 0Ah, '    enable GC: <TypeA>, <TypeB>', 0Ah, 0Ah
msg_err_gc_ru_len   = $ - msg_err_gc_ru

msg_err_kids_en:    db 0Ah, "[-] Compilation Error: Educational commands (say, repeat) require Kids mode:", 0Ah, '    mode "kids"', 0Ah, 0Ah
msg_err_kids_en_len = $ - msg_err_kids_en
msg_err_kids_ru:    db 0Ah, "[-] Ошибка компиляции: Обучающие команды (say, repeat) требуют режима Kids:", 0Ah, '    mode "kids"', 0Ah, 0Ah
msg_err_kids_ru_len = $ - msg_err_kids_ru

msg_err_syn_en:     db 0Ah, "[-] Syntax Error at unexpected token:", 0Ah
msg_err_syn_en_len  = $ - msg_err_syn_en
msg_err_syn_ru:     db 0Ah, "[-] Синтаксическая ошибка. Неожиданный токен:", 0Ah
msg_err_syn_ru_len  = $ - msg_err_syn_ru

nl_char:            db 0x0A
space_char:         db 0x20
caret_char:         db "^", 0x0A

default_out:        db "output", 0
default_out_rse:    db "output.rse", 0

src_filename:       dq 0
out_filename:       dq 0
src_fd:             dq 0
out_fd:             dq 0
code_size:          dq 0
exec_mem:           dq 0
code_start_ptr:     dq 0
is_jit_mode:        db 0
is_rse_mode:        db 0
is_run_mode:        db 0
lang_ru:            db 0
is_loser_mode:      db 0
is_osdev_mode:      db 0
is_sys_mode:        db 0
is_vars_mode:       db 0
is_logic_mode:      db 0
is_gc_enabled:      db 0
is_kids_mode:       db 0
is_blocks_enabled:  db 0

align 8
gc_targets_count:     dq 0
blocks_targets_count: dq 0
gc_targets_table:     rb 1024
blocks_targets_table: rb 1024

repeat_stack:       rq 16
repeat_depth:       dq 0

vars_table:         rb 64 * 32
vars_count:         dq 0
curr_var_offset:    dq 0

labels_table:       rb 64 * 16
labels_count:       dq 0

src_buf:            rb 1048576
tokens_buf:         rb 16 * 65536
ast_buf:            rb 32 * 65536
code_buf:           rb 1048576
