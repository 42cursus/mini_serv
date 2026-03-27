;int	extract_message(char **bufferPointer, char **msg)
;{
;	char *buf = *bufferPointer;
;	char *new_line = NULL;
;	char *src = NULL;
;	char *new_buf = NULL;
;
;	*msg = NULL;
;	if (buf == NULL)
;		goto ret0;
;	new_line = strchrnul(buf, '\n');
;	if (*new_line == '\0')
;		goto ret0;
;
;	src = new_line + 1;
;	new_buf = calloc(1, strlen(src) + 1);
;	if (new_buf == NULL)
;		goto retneg1;
;
;	strcpy(new_buf, src);
;	*msg = buf;
;	*src = '\0';
;	*bufferPointer = new_buf;
;	return 1;
;ret0:
;	return 0;
;retneg1:
;	return -1;
;}

bits 64
default rel

%define NULL  0

%define msg_off            48
%define bufferPointer_off  40
%define buf_off            32
%define new_line_off       24
%define src_off            16
%define new_buf_off         8

%define msg                qword [rbp - msg_off]			; QWORD PTR -48[rbp]
%define bufferPointer      qword [rbp - bufferPointer_off]	; QWORD PTR -40[rbp]

%define buf                qword [rbp - buf_off]			; QWORD PTR -32[rbp]
%define new_line           qword [rbp - new_line_off]		; QWORD PTR -24[rbp]
%define src                qword [rbp - src_off]			; QWORD PTR -16[rbp]
%define new_buf            qword [rbp - new_buf_off]		; QWORD PTR -8[rbp]

SECTION .data			  ; Section containing initialized data
SECTION .bss              ; Section containing uninitialized data
SECTION .text			  ; Section containing code

extern strcpy
extern calloc
extern strlen
extern strchrnul

global   extract_message
extract_message:
	push	rbp
	mov	rbp, rsp
	sub	rsp, 48

    ; save arguments
    mov bufferPointer, rdi
    mov msg, rsi

    ; char *buf = *bufferPointer;
    mov rax, bufferPointer
    mov rax, qword [rax]
    mov buf, rax

    mov new_line, NULL  ; char *new_line = NULL;
    mov src, NULL       ; char *src = NULL;
    mov new_buf, NULL   ; char *new_buf = NULL;

	; *msg = NULL;
	mov rax, msg
	mov qword [rax], NULL

	; if (buf == NULL) goto ret0;
	cmp buf, NULL
	je	.ret_0

	; new_line = strchrnul(buf, '\n');
	mov rdi,buf               ;
	mov rsi,10                ; '\n'
	call strchrnul wrt ..plt  ; Call libc function
	mov new_line, rax

	; if (*new_line == '\0') goto ret0;
	mov   rax, new_line
    cmp   byte [rax], 0
    je    .ret_0

	; src = new_line + 1;
	mov	rax, new_line
	add	rax, 1
	mov	src, rax

	; strlen(src) + 1
	mov	rdi, src
	call strlen wrt ..plt  ; Call libc function
	add	rax, 1

	; new_buf = calloc(1, ...);
	mov	rsi, rax
	mov	edi, 1
	call calloc wrt ..plt  ; Call libc function
	mov	new_buf, rax

	; if (new_buf == NULL) goto retneg1;
    cmp   new_buf, NULL
    je    .ret_neg1

	; strcpy(new_buf, src);
	mov	rsi, src
	mov	rdi, new_buf
	call strcpy wrt ..plt  ; Call libc function

	; *msg = buf;
	mov	rax, msg
	mov	rdx, buf
	mov	qword [rax], rdx

	; *src = '\0';
	mov	rax, src
	mov	byte [rax], 0

	; *bufferPointer = new_buf;
	mov	rax, bufferPointer
	mov	rdx, new_buf
	mov	qword [rax], rdx

.ret_1:
	mov	eax, 1
	jmp	.LEAVE
.ret_0:
	mov	eax, 0
	jmp	.LEAVE
.ret_neg1:
	mov	eax, -1
.LEAVE:
	leave
	ret
