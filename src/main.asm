; src/main.asm -- Aether V1 compiler (bootstrap, NASM, x86-64 Linux)
; Builds: nasm -f elf64 src/main.asm -o build/main.o && ld build/main.o -o build/aetherc

section .data
    usage db "aetherc V1 - usage: aetherc <input.ae|.aeth>... -o <out>", 10
    usage_len equ $ - usage
    ver db "aetherc 1.0.0 (bootstrap/asm)", 10
    ver_len equ $ - ver

section .text
    global _start

_start:
    ; print version
    mov rax, 1
    mov rdi, 1
    lea rsi, [rel ver]
    mov rdx, ver_len
    syscall

    ; print usage
    mov rax, 1
    mov rdi, 1
    lea rsi, [rel usage]
    mov rdx, usage_len
    syscall

    ; exit 0
    mov rax, 60
    xor rdi, rdi
    syscall
