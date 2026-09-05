
align 8
mbr_template:
use16
    cli
    cld
    xor ax, ax
    mov ds, ax
    mov es, ax
    mov ss, ax
    mov sp, 0x7C00

    mov bx, 0x8000
    mov ah, 0x02
    mov al, 32
    mov ch, 0
    mov cl, 2                  
    mov dh, 0
    int 0x13
    
    db 0x73, 0x07

    mov ax, 0x0E00 + 'E'
    int 0x10
    cli
    hlt

    mov di, 0x1000
    mov cx, 0x1800             ; Очищаем 12 КБ (PML4 + PDPT + PD)
    xor ax, ax
    rep stosw

    ; PML4[0] -> PDPT (0x2000)
    mov word [0x1000], 0x2003  ; Present | Writable
    ; PDPT[0] -> PD (0x3000)
    mov word [0x2000], 0x3003  ; Present | Writable
    ; PD[0] -> 2MB Page (0x00000000..0x001FFFFF)
    mov word [0x3000], 0x0083  ; Present | Writable | HugePage (2MB)

    ; Загружаем GDT
    lgdt [mbr_gdt_desc - mbr_template + 0x7C00]

    ; Включаем PAE в CR4 (бит 5)
    mov eax, cr4
    bts eax, 5
    mov cr4, eax

    ; Загружаем PML4 в CR3
    mov eax, 0x1000
    mov cr3, eax

    ; Активируем Long Mode в MSR EFER (0xC0000080, бит 8 = LME)
    mov ecx, 0xC0000080
    rdmsr
    bts eax, 8
    wrmsr

    ; Включаем страничную адресацию (PG) и защиту (PE) в CR0
    mov eax, cr0
    bts eax, 31                ; PG = 1
    bts eax, 0                 ; PE = 1
    mov cr0, eax

    ; Far Jump в 64-битный сегмент кода GDT (селектор 0x08)
    db 0xEA
    dw mbr_entry64 - mbr_template + 0x7C00
    dw 0x0008

align 8
mbr_gdt:
    dq 0                       ; Нулевой дескриптор
    dq 0x00AF9A000000FFFF      ; 0x08: 64-bit Code (L=1, D=0, DPL=0)
    dq 0x00CF92000000FFFF      ; 0x10: 64-bit Data (W=1, DPL=0)
mbr_gdt_end:

mbr_gdt_desc:
    dw mbr_gdt_end - mbr_gdt - 1
    dd mbr_gdt - mbr_template + 0x7C00

use64
mbr_entry64:
    xor ax, ax
    mov ds, ax
    mov es, ax
    mov ss, ax
    mov fs, ax
    mov gs, ax
    mov rsp, 0x7C00

    ; Переход на точку входа ядра RamisScript (сектор 2 = 0x8000)
    mov rax, 0x8000
    jmp rax

MBR_SIZE = $ - mbr_template
times 510 - MBR_SIZE db 0
dw 0xAA55
use64
