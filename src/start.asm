; start.asm
BITS 64

default rel

extern __libc_start_main
extern main

global _start:function (_start.end - _start)
section .text
..@text_pad:
    nop

_start:
    xor ebp, ebp                ; conventional outermost frame marker
    mov r12, rdx                ; Preserve rtld_fini from dynamic linker

    ; Grab argc and argv before we do any pushes
    pop rsi                     ; argc
    mov rdx, rsp                ; argv

    mov r13, rsi                ; argc
    mov r14, rdx                ; argv

    and rsp, -16                ; align stack
    push rax                    ; padding / dummy
    push rsp                    ; 7th arg: stack_end

    lea rdi, [main]    ; main function
    mov rsi, r13       ; argc
    mov rdx, r14       ; argv
    xor rcx, rcx       ; init = 0
    xor r8,  r8        ; fini = 0
    mov r9, r12		   ; rtld_fini = from dynamic linker

    call __libc_start_main wrt ..plt

    ; Should not return. If it does, call exit(1).
    mov edi, 1
    mov eax, 60
    syscall

	ud2
.end:
