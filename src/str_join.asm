bits 64
default rel

%define NULL  0

%define len       r14 ;
%define chr_ptr   r13 ;
%define to_add    r12 ;
%define buf       rbx ;
%define new_buf   qword[rbp - 40] ; QWORD PTR -40[rbp]

SECTION .data			  ; Section containing initialized data
SECTION .rodata			  ; Section containing initialized read-only data

;SECTION .rodata.str1.1 progbits alloc noexec nowrite align=1 merge strings
LC0: db "", 0

SECTION .bss              ; Section containing uninitialized data
SECTION .text.pad exec nowrite align=1
    nop
SECTION .text			  ; Section containing code

extern strlen
extern strcat
extern malloc
extern free

global   str_join:function (str_join.end - str_join)

; char	*str_join(char *buf, char *add);
str_join:
	push	rbp
	mov	rbp, rsp
	push	r14
	push	r13
	push	r12
	push	rbx
	sub	rsp, 16 ; 1 slot of 8 bytes + 8 bytes to keep stack aligned to 16 as per SysV ABI

	; save arguments
	mov	buf, rdi ; buf
	mov	to_add, rsi ; to_add

	; const char *chr_ptr = buf ? buf : "";
	test	rdi, rdi
	lea	chr_ptr, [rel LC0]
	cmovne	chr_ptr, buf

	; size_t len = strlen(chr_ptr);
	mov	rdi, chr_ptr
	call	strlen wrt ..plt
	mov	len, rax

	; char *new_buf = malloc((len + strlen(add) + 1) * sizeof(char));
	mov	rdi, to_add
	call	strlen wrt ..plt
	lea	rdi, [len + rax + 1]
	call	malloc wrt ..plt
	mov	new_buf, rax

	; if (new_buf != NULL) goto .result;
	mov	rax, new_buf
	test	rax, rax
	je	.result

.new_buf_is_ok:
	; new_buf[0] = '\0';
	mov	byte [rax], 0

	; strcat(new_buf, chr_ptr);
	mov	rsi, chr_ptr
	mov	rdi, new_buf
	call	strcat wrt ..plt

	; free(buf);
	mov	rdi, buf
	call	free wrt ..plt

	; strcat(new_buf, add);
	mov	rsi, to_add
	mov	rdi, new_buf
	call	strcat wrt ..plt

.result:
	mov	rax, new_buf
	add	rsp, 16
	pop	rbx
	pop	r12
	pop	r13
	pop	r14
	pop	rbp
	ret
.end:
