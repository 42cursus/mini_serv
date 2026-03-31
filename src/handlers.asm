bits 64
default rel

%define connfd								dword[rbp - 40] ; DWORD PTR -40[rbp]
%define client_addr_len						dword[rbp - 36] ; DWORD PTR -36[rbp]
%define client_addr__sin_family				word[rbp - 32] ; WORD PTR -32[rbp]
%define client_addr__sin_port				word[rbp - 30] ; WORD PTR -30[rbp]
%define client_addr__sin_addr__s_addr		dword[rbp - 28] ; DWORD PTR -28[rbp]
%define client_addr__sin_zero_b				byte[rbp - 24] ; BYTE PTR -24[rbp]
%define client_addr__sin_zero_q				qword[rbp - 24] ; QWORD PTR -24[rbp]

%define sizeof_client_addr          		16 ;
%define sizeof_t_client		          		16 ;
%define AF_INET          					2 ;
%define NFDBITS          					64 ;

SECTION .data			  ; Section containing initialized data

extern next_id

SECTION .rodata			  ; Section containing initialized read-only data

LC0: db `server: client %d just arrived\n`,0

SECTION .bss              ; Section containing uninitialized data

extern max_fd
extern clients
extern buf_send
extern master_fds

SECTION .text			  ; Section containing code

extern sprintf
extern accept
extern send_all

global   try_accept

try_accept:
	push	rbp
	mov	rbp, rsp
	push	r12
	push	rbx
	sub	rsp, 32

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
	mov	qword [rax + 8], 0

	; register char *buf_send_ptr asm("r12") = buf_send;
	lea	r12, [rel buf_send]

	; __builtin_sprintf(buf_send_ptr, "server: client %d just arrived\n", client->id);
	mov     eax, connfd            ;
	cdqe                           ; sign-extend eax -> rax
	sal     rax, 4                 ; shift arifmetic left by 4 == multiply by sizeof(t_client) = 16
	lea     rdx, [rel clients]     ;
	mov     edx, dword [rdx + rax] ; load clients[connfd].id to edx

	lea	rsi, [rel LC0]
	mov	rdi, r12
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
