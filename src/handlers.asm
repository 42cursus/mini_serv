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
LC3: db `client %d: %s`,0

SECTION .bss              ; Section containing uninitialized data

extern max_fd
extern clients
extern buf_send
extern buf_read
extern master_fds

SECTION .text			  ; Section containing code

extern sprintf
extern accept
extern close
extern free
extern str_join
extern send_all
extern extract_message

global   try_accept
global   handle_leave
global   handle_read

; --- X86_64 SysV ABI ---
; https://wiki.osdev.org/System_V_ABI
; The first six integer and pointer arguments are passed like this:
;	arg1: rdi
;	arg2: rsi
;	arg3: rdx
;	arg4: rcx
;	arg5: r8
;	arg6: r9

; void handle_read(int sockfd, int fd, int bytes)
handle_read:
	push	rbp
	mov	rbp, rsp
	push	r15
	push	r14
	push	r13
	push	r12
	push	rbx
	sub	rsp, 24

	%define msg_to_send_off			56 ;
	%define t_client_id_off			0 ; client->id
	%define t_client_msg_off		8 ; client->msg
	%define msg_to_send_slot		[rbp - msg_to_send_off] ; QWORD PTR -56[rbp]
	%define msg_to_send				qword[rbp - 56] ; QWORD PTR -56[rbp]

	; save arguments
	mov	r13d, edi					; sockfd
	mov	r12d, esi					; fd
	mov	edx, edx					; bytes

	; char *msg_to_send = NULL;
	mov	msg_to_send, 0

	; int id = clients[fd].id;
	movsx	rax, r12d				; rax = (int64_t)fd (signed extend)
	sal	rax, 4						; rax = fd * sizeof(t_client) == (int64_t)fd << __builtin_ctz(sizeof(t_client))
	lea	rbx, [rel clients]
	add	rbx, rax					; rbx = &clients[fd]
	mov	r15d, dword [rbx + t_client_id_off]		; r15d = client->id

	; char **msg = &clients[fd].msg;
	lea	r14, [rbx + t_client_msg_off]				; r14 = &client->msg

	; buf_read[bytes] = 0;
	lea	rsi, [rel buf_read]
	movsx	rdx, edx
	mov	byte [rsi + rdx], 0

	; *msg = str_join(*msg, buf_read);
	mov	rsi, rsi					; rsi = buf_read
	mov	rdi, qword [r14]			; rdi = *msg
	call	str_join wrt ..plt
	mov	qword [r14], rax

L1_loop_start:
	; int extractResult = extract_message(msg, &msg_to_send);
	lea	rsi, msg_to_send_slot		; rsi = msg_to_send
	mov	rdi, r14					; rdi = msg
	call	extract_message wrt ..plt
	jmp	L1_loop_iter
L1_loop_body:
	; const char *format = "client %d: %s";
	lea	rsi, [rel LC3]

	; char *bufSend = &buf_send[0];
	lea	rbx, [rel buf_send]

	; sprintf(bufSend, format, id, msg_to_send);
	mov	rcx, msg_to_send			; msg_to_send
	mov	edx, r15d					; id
	mov	rsi, rsi					; format
	mov	rdi, rbx					; bufSend
	mov	eax, 0
	call	sprintf wrt ..plt

	; send_all(fd, sockfd, bufSend);
	mov	rdx, rbx					; rdx = bufSend
	mov	esi, r13d					; esi = sockfd
	mov	edi, r12d					; edi = fd
	call	send_all wrt ..plt

	; free(msg_to_send);
	mov	rdi, msg_to_send
	call	free wrt ..plt

	; msg_to_send = NULL;
	mov	msg_to_send, 0

	; extractResult = extract_message(msg, &msg_to_send);
	lea	rsi, msg_to_send_slot
	mov	rdi, r14
	call	extract_message wrt ..plt
L1_loop_iter:
	test	eax, eax
	jne	L1_loop_body

L1_loop_end:
	add	rsp, 24
	pop	rbx
	pop	r12
	pop	r13
	pop	r14
	pop	r15
	pop	rbp
	ret

;void	handle_leave(int sockfd, int fd);
handle_leave:
	push	rbp
	mov	rbp, rsp
	push	r14
	push	r13
	push	r12
	push	rbx

	; save arguments
	mov	r13d, edi				; int sockfd
	mov	ebx, esi				; int fd

	; -- sprintf(buf_send, "server: client %d just left\n", clients[fd].id); --
	; 	size_t offset = fd * sizeof(clients[0]);
	; same as:
	; 	size_t offset = (int64_t)fd << __builtin_ctz(sizeof(clients[0]));
	movsx	r12, esi			; r12 = (int64_t)fd // signed extend
	sal	r12, 4					; r12 = r12 * 16	// mul via shift arifmetic left by log2(sizeof(t_client))

	; int id = *(int *)((char *)clients + offset);
	lea	rax, [rel clients]
	add r12, rax 				; r12 holds the pointer &clients[fd]
	mov	edx, dword [r12 + 0]	; `id` is at offset 0 inside the `t_client` struct

	; const char *string = "server: client %d just left\n";
	lea	rax, [rel LC2]

	mov	rsi, rax				; format string

	; char *bufSend = *(&buf_send[0]);
	lea	r14, [rel buf_send]

	mov	rdi, r14				; buffer

	mov	eax, 0					; al = number of vector registers (XMM) used to pass floating-point arguments
	call	sprintf wrt ..plt

	; send_all(fd, sockfd, buf_send);
	mov	rdx, r14	; buf_send
	mov	esi, r13d	; int sockfd
	mov	edi, ebx	; int fd
	call	send_all wrt ..plt

	; -- FD_CLR(fd, &master_fds); --
	; same as `(void) (master_fds.fds_bits[__FD_ELT(fd)] &= ~__FD_MASK(fd));`

	; unsigned irem = (unsigned)fd % NFDBITS; same as: (unsigned)fd & (NFDBITS - 1);
	; ensures irem < 64
	mov	ecx, ebx
	and	ecx, 63					; (unsigned)fd & (NFDBITS - 1);

	; __fd_mask mask = (__fd_mask) (1UL << irem);
	mov	edx, 1					; 1UL
	sal	rdx, cl					; rdx <<= cl; (cl is the low 8 bits of $rcx)

	; __fd_mask *fds_bits = master_fds.fds_bits;
	lea	rcx, [rel master_fds]

	; unsigned iquot = (unsigned)fd / NFDBITS; == (unsigned)fd >> __builtin_ctz(NFDBITS);
	mov	eax, ebx				; eax = fd
	shr	eax, 6					; eax = eax >> log2(NFDBITS)

	; (void)(fds_bits[iquot] &= ~mask);
	mov	eax, eax				; zero-extend EAX into RAX for 64-bit indexed addressing (like movzx rax, eax)
	not	rdx						; ~mask
	and	qword [rcx+rax*8], rdx

	; close(fd);
	mov	edi, ebx
	call	close wrt ..plt

	; if (clients[fd].msg == NULL) goto clear;
	mov	rdi, qword [r12 + 8]	; `msg` is at offset 8 inside the `t_client` struct
	test	rdi, rdi
	je	clear
	call	free wrt ..plt
clear:
	;clients[fd].msg = NULL;
	movsx	rbx, ebx			; sign-extend 32-bit fd into 64-bit rbx
	sal	rbx, 4
	lea	rax, [rel clients]
	mov	qword [rax + rbx + 8], NULL

	pop	rbx
	pop	r12
	pop	r13
	pop	r14
	pop	rbp
	ret

; void	try_accept(int sockfd);
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
