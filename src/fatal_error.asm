;void fatal_error()
;{
;	char *err = "Fatal error\n";
;	write(STDERR_FILENO, err, strlen(err));
;	exit(EXIT_FAILURE);
;}

bits 64
default rel

%define EXIT_FAILURE  1
%define STDERR_FILENO 2
%define sys_write     1
%define sys_exit      60

SECTION .rodata			; Section containing initialized data

err_msg: db `Fatal error\n`, 0
err_msg_len: equ ($ - err_msg) - 1

SECTION .bss				; Section containing uninitialized data
SECTION .text				; Section containing code
..@text_pad:
    nop

global   fatal_error:function (fatal_error.end - fatal_error)

fatal_error:
    push rbp
    mov  rbp, rsp

	mov rax,sys_write     ; 1 = sys_write for syscall
	mov rdi,STDERR_FILENO ; 2 = fd for stderr; write to the terminal window
	lea rsi,[rel err_msg] ; Put address of the message string in rsi
	mov rdx,err_msg_len   ; Length of string to be written in rdx
	syscall               ; Make the system call

	mov rax,sys_exit      ; 60 = exit the program
	mov rdi,EXIT_FAILURE  ; Return value in rdi 1
	syscall               ; Call syscall to exit

	ud2
.end:
