bits 64
default rel

%assign NULL	          					0  ;
%assign AF_INET          					2  ;
%assign NFDBITS          					64 ;
%assign sizeof_client_addr          		16 ;
%assign sizeof_t_client		          		16 ;

SECTION .data			  ; Section containing initialized data

extern next_id

SECTION .rodata			  ; Section containing initialized read-only data

LC1: db `server: client %d just arrived\n`,0
LC2: db `server: client %d just left\n`,0

SECTION .bss              ; Section containing uninitialized data

extern max_fd
extern clients
extern buf_send
extern master_fds

SECTION .text			  ; Section containing code

extern sprintf
extern accept
extern close
extern free
extern send_all

global   try_accept
global   handle_leave

handle_leave:
	push	rbp
	mov	rbp, rsp
	push	r14
	push	r13
	push	r12
	push	rbx
	mov	r13d, edi
	mov	ebx, esi

	; sprintf(buf_send, "server: client %d just left\n", clients[fd].id);
	movsx	rax, esi
	sal	rax, 4
	lea	r12, [rel clients]
	add	r12, rax
	mov	rdx, qword [r12]
	lea	rsi, [rel LC2]
	lea	r14, [rel buf_send]
	mov	rdi, r14
	mov	eax, 0
	call	sprintf wrt ..plt

	; send_all(fd, sockfd, buf_send);
	mov	rdx, r14
	mov	esi, r13d
	mov	edi, ebx
	call	send_all wrt ..plt

	; FD_CLR(fd, &master_fds);
	lea	eax, [rbx + 63]
	test	ebx, ebx
	cmovns	eax, ebx
	sar	eax, 6
	mov	edx, 1
	mov	ecx, ebx
	sal	rdx, cl
	not	rdx
	lea	rcx, [rel master_fds]
	cdqe
	and	qword [rcx+rax*8], rdx

	; close(fd);
	mov	edi, ebx
	call	close wrt ..plt

	; if (clients[fd].msg) goto clear;
	mov	rdi, qword [r12 + 8]
	test	rdi, rdi
	je	clear
	call	free wrt ..plt
clear:
	;clients[fd].msg = NULL;
	movsx	rbx, ebx
	sal	rbx, 4
	lea	rax, [rel clients]
	mov	qword [rax + rbx + 8], NULL

	pop	rbx
	pop	r12
	pop	r13
	pop	r14
	pop	rbp
	ret

try_accept:
	push	rbp
	mov	rbp, rsp
	push	r12
	push	rbx
	sub	rsp, 32

	%define connfd								dword[rbp - 40] ; DWORD PTR -40[rbp]
	%define client_addr_len						dword[rbp - 36] ; DWORD PTR -36[rbp]
	%define client_addr__sin_family				word[rbp - 32] ; WORD PTR -32[rbp]
	%define client_addr__sin_port				word[rbp - 30] ; WORD PTR -30[rbp]
	%define client_addr__sin_addr__s_addr		dword[rbp - 28] ; DWORD PTR -28[rbp]
	%define client_addr__sin_zero_b				byte[rbp - 24] ; BYTE PTR -24[rbp]
	%define client_addr__sin_zero_q				qword[rbp - 24] ; QWORD PTR -24[rbp]

    ; save arguments
	mov	ebx, edi

	mov	client_addr_len, sizeof_client_addr
	mov	client_addr__sin_family, AF_INET
	mov	client_addr__sin_port, 0
	mov	client_addr__sin_addr__s_addr, 0
	mov	client_addr__sin_zero_q, 0

	; int connfd = accept(sockfd, (struct sockaddr *)&client_addr, &len);
	lea	rsi, word[rbp - 32]
	lea	rsi, client_addr__sin_family
	lea	rdx, client_addr_len
	call	accept wrt ..plt
	mov	connfd, eax

	; if (connfd < 0) goto do_return;
	test	eax, eax
	js	do_return

	; max_fd = (connfd > max_fd) ? connfd : max_fd;
	mov	eax, connfd ; <= actually not needed, as eax already hold the connfd
	mov	edx, dword [rel max_fd]
	cmp	eax, edx
	cmovl	eax, edx
	mov	dword [rel max_fd], eax

	; size_t byte_offset = connfd * sizeof(t_client);
	mov	rdx, sizeof_t_client
	mov	ecx, connfd
	movsx	rax, ecx
	imul	rax, rdx

	; t_client *client = (t_client *) ((char *) &clients[0] + byte_offset);
	lea	rdx, [rel clients]
	add	rax, rdx

	; client->id = next_id++;
	mov	rdx, qword [rel next_id]
	lea	rsi, [rdx + 1] ; just a leal trick: rsi = rdx + 1
	mov	qword [rel next_id], rsi
	mov	qword [rax], rdx

	; client->msg = NULL;
	mov	qword [rax + 8], NULL

	; register char *buf_send_ptr asm("r12") = buf_send;
	lea	r12, [rel buf_send]

	; __builtin_sprintf(buf_send_ptr, "server: client %d just arrived\n", client->id);
	mov     eax, connfd            ;
	cdqe                           ; sign-extend eax -> rax
	sal     rax, 4                 ; shift arifmetic left by 4 == multiply by sizeof(t_client) = 16
	lea     rdx, [rel clients]     ;
	mov     edx, dword [rdx + rax] ; load clients[connfd].id to edx

	lea	rsi, [rel LC1]			   ; "server: client %d just arrived\n"
	mov	rdi, r12				   ; buf_send_ptr
	mov	eax, 0
	call	sprintf wrt ..plt

	; send_all(connfd, sockfd, buf_send_ptr);
	mov	rdx, r12		; buf_send
	mov	esi, ebx		; sockfd
	mov	edi, connfd		; connfd
	call	send_all wrt ..plt


	; --- FD_SET(connfd, &master_fds); ---
	; register int r asm("r8") = (connfd % NFDBITS);
	; register int FD_ELT asm("r9") = (connfd / NFDBITS);
	mov	ecx, NFDBITS
	mov	eax, connfd
	cdq 						; sign-extend EAX into EDX:EAX
	idiv	ecx
	mov	r8d, edx				; (connfd % NFDBITS)
	mov	r9d, eax				; (connfd / NFDBITS)

	; __fd_mask fdMask = (__fd_mask) (1UL << (connfd % NFDBITS)); 	__FD_MASK(connfd);
	mov	eax, 1			; 1UL
	mov	ecx, r8d		; (connfd % NFDBITS)
	sal	rax, cl			; shift arithmetic left: (1UL << r8d)
	mov	rcx, rax		; fdMask <= rax

	; __fd_mask *fds_bits = master_fds.fds_bits;
	lea	rdx, [rel master_fds]

	; (void) (fds_bits[__FD_ELT(connfd)] |= fdMask);
	movsx	r9, r9d
	lea	rdx, [rel master_fds]
	or	qword [rdx+r9*8], rax

do_return:
	add	rsp, 32
	pop	rbx
	pop	r12
	pop	rbp
	ret
