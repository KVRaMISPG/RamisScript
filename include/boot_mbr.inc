virtual at 0x7C00
use16
mbr_core:
    cli
    cld
    xor ax, ax
    mov ds, ax
    mov es, ax
    mov ss, ax
    mov sp, 0x7C00

    mov [mbr_drive], dl

    mov bx, 0x8000
    mov ah, 0x02
    mov al, 32
    mov ch, 0
    mov cl, 2
    mov dh, 0
    mov dl, [mbr_drive]
    int 0x13
    jc mbr_disk_err

    mov di, 0x1000
    mov cx, 0x1800
    xor ax, ax
    rep stosw

    mov word [0x1000], 0x2003
    mov word [0x2000], 0x3003
    mov word [0x3000], 0x0083

    lgdt [mbr_gdt_desc]

    mov eax, cr4
    bts eax, 5
    mov cr4, eax

    mov eax, 0x1000
    mov cr3, eax

    mov ecx, 0xC0000080
    rdmsr
    bts eax, 8
    wrmsr

    mov eax, cr0
    bts eax, 31
    bts eax, 0
    mov cr0, eax

    db 0xEA
    dw mbr_entry64
    dw 0x0008

mbr_disk_err:
    mov ax, 0x0E00 + 'E'
    int 0x10
    cli
    hlt

align 8
mbr_gdt:
    dq 0
    dq 0x00AF9A000000FFFF      
    dq 0x00CF92000000FFFF     
mbr_gdt_end:

mbr_gdt_desc:
    dw mbr_gdt_end - mbr_gdt - 1
    dd mbr_gdt

mbr_drive:
    db 0

use64
mbr_entry64:
    xor ax, ax
    mov ds, ax
    mov es, ax
    mov ss, ax
    mov fs, ax
    mov gs, ax
    mov rsp, 0x7C00

    mov rax, 0x8000
    jmp rax

MBR_ACTUAL_SIZE = $ - mbr_core
end virtual
use64

align 8
mbr_template:
    repeat MBR_ACTUAL_SIZE
        load _b byte from mbr_core + % - 1
        db _b
    end repeat
    times 510 - MBR_ACTUAL_SIZE db 0
    dw 0xAA55