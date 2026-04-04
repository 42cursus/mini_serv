bits 64
default rel

%assign EXIT_FAILURE	1
%assign EXIT_OK			0
%assign STDERR_FILENO	2
%assign SIGINT			2
%assign sys_write		1
%assign sys_exit		60
%assign sizeof_fd_set	0x80 ; 128 == FD_SETSIZE / NFDBITS

SECTION .rodata			; Section containing initialized data

err_arg_msg: db `Wrong number of arguments\n`, 0
err_arg_len: equ ($ - err_arg_msg) - 1

SECTION .bss				; Section containing uninitialized data
SECTION .text				; Section containing code

extern write
extern exit
extern init
extern memmove
extern memcpy
extern select
extern try_accept
extern recv
extern handle_leave
extern handle_read

extern g_var
extern buf_read
extern max_fd
extern master_fds
extern read_fds

global   main

; int main(register int argc_r, register char *argv_r[]);
main:
	push	rbp
	mov	rbp, rsp
	push	r14
	push	r13
	push	r12
	push	rbx

	; save arguments
	mov	r13d, edi
	mov	r14, rsi

	; if (argc == 2) goto pass;
	cmp	r13d, 2
	je	pass

	; write(STDERR_FILENO, "Wrong number of arguments\n", sizeof("Wrong number of arguments\n") - 1);
	lea	rsi, [rel err_arg_msg]
	mov	edx, err_arg_len
	mov	edi, STDERR_FILENO
	call	write wrt ..plt

	; exit(1);
	mov	edi, EXIT_FAILURE
	call	exit wrt ..plt

pass:
	; int sockfd = init(argv);
	mov	rdi, r14					; rdi = argv
	call	init
	mov	r12d, eax					; r12d = sockfd

event_loop_start:
	jmp	event_loop_iter

event_loop_body:

	; read_fds = master_fds;
	mov	edx, sizeof_fd_set
	lea	rsi, [rel master_fds]
	lea	rbx, [rel read_fds]
	mov	rdi, rbx
	call	memcpy wrt ..plt

	; int  fd_num = select(max_fd + 1, &read_fds, NULL, NULL, NULL);
	mov	eax, dword [rel max_fd]
	lea	edi, [rax + 1]
	mov	r8d, 0
	mov	ecx, 0
	mov	edx, 0
	mov	rsi, rbx
	call	select wrt ..plt

	; if (fd_num < 0) goto fd_loop_end;
	test	eax, eax
	js	fd_loop_end

fd_loop_start:

	; int fd = -1;
	mov	ebx, -1
	jmp	fd_loop_iter

fd_loop_body:
	; register _Bool is_set = FD_ISSET(fd, &read_fds);
	lea	eax, [rbx + 63]
	test	ebx, ebx
	cmovns	eax, ebx
	sar	eax, 6
	cdqe

	mov	edx, 1
	mov	ecx, ebx
	sal	rdx, cl

	lea	rcx, [rel read_fds]
	test	qword [rcx + rax*8], rdx
	setne	al

	; if (!is_set) goto fd_is_not_set;
	test	al, al
	je	fd_is_not_set

	; if (fd != sockfd) goto fd_neq_sockfd;
	cmp	r12d, ebx
	jne	fd_neq_sockfd

do_accept:
	; try_accept(sockfd);
	mov	edi, r12d
	call	try_accept wrt ..plt
	jmp	fd_loop_iter

fd_neq_sockfd:
	; int bytes = recv(fd, buf_read, 8192, 0);
	mov	ecx, 0
	mov	edx, 8192
	lea	rsi, [rel buf_read]
	mov	edi, ebx
	call	recv wrt ..plt
	mov	edx, eax

	; if (bytes <= 0)
	test	eax, eax
	jg	bytes_recv_gt_zero

bytes_recv_lte_zero:
	mov	esi, ebx
	mov	edi, r12d
	call	handle_leave wrt ..plt	; void	handle_leave(int sockfd, int fd);
	jmp	fd_loop_iter

bytes_recv_gt_zero:
	mov	esi, ebx
	mov	edi, r12d
	call	handle_read wrt ..plt	; void	handle_read(int sockfd, int fd, int bytes);

fd_is_not_set:
; while (++fd <= max_fd)
fd_loop_iter:
	add	ebx, 1
	cmp	dword [rel max_fd], ebx
	jge	fd_loop_body

fd_loop_end:
event_loop_iter:
	cmp	dword [rel g_var], SIGINT
	jne	event_loop_body

event_loop_end:
	mov	eax, 0
	pop	rbx
	pop	r12
	pop	r13
	pop	r14
	pop	rbp
	ret
