;void send_all(int sender_fd, int sockfd, char *msg)
;{
;	for (int fd = 0; fd <= max_fd; fd++) {
;		if (FD_ISSET(fd, &master_fds) && fd != sender_fd && fd != sockfd)
;			send(fd, msg, strlen(msg), 0);
;	}
;}

bits 64
default rel

%define NULL  0

%define msg_len            qword[rbp - 24] ; QWORD PTR -24[rbp]
%define fds_bits_ptr       qword[rbp - 32] ; QWORD PTR -32[rbp]
%define sender_fd          dword[rbp - 36] ; DWORD PTR -36[rbp]
%define sockfd             dword[rbp - 40] ; DWORD PTR -40[rbp]
%define msg                qword[rbp - 48] ; QWORD PTR -48[rbp]
%define fd                 ebx ;

%define NFDBITS          64 ;

SECTION .data			  ; Section containing initialized data
SECTION .rodata			  ; Section containing initialized read-only data
SECTION .bss              ; Section containing uninitialized data

extern max_fd
extern master_fds

SECTION .text			  ; Section containing code

extern strlen
extern send


global   send_all
global   loop_start:hidden
global   loop_fd:hidden
global   loop_end:hidden

; void	send_all(int sender_fd, int sockfd, char *msg);
send_all:
	push	rbp
	mov	rbp, rsp
	push	r12
	push	rbx
	sub	rsp, 32

    ; save arguments
	mov	sender_fd, edi
	mov	sockfd, esi
	mov	msg, rdx

	lea     rax, [rel master_fds]
	mov     fds_bits_ptr, rax

	mov	rdi, msg
	call strlen wrt ..plt  ; Call libc function
	mov	msg_len, rax

L2_loop_start:
	mov	fd, -1
	jmp L2_loop_iter;

L2_loop_body:
	; register unsigned int i = NFDBITS;
	mov	r12d, NFDBITS     ; NFDBITS = 64

	; r10d = (fd / NFDBITS);
	mov	eax, fd
	mov	edx, 0
	div	r12d
	mov	r10d, eax

	; r11d = (fd % NFDBITS)
	mov	eax, fd
	mov	edx, 0
	div	r12d
	mov	r11d, edx

	; mask = (__fd_mask) (1UL << r11d)
	mov	ecx, r11d			;
	mov	eax, 1				;
	sal	rax, cl				;
	mov	r12, rax			; r12 = (__fd_mask) (1UL << r11d)

	; register _Bool is_set = (fds_bits[idx] & mask) != 0;
	mov	eax, r10d			;
	lea	rdx, 0[0+rax*8]
	mov	rax, fds_bits_ptr
	mov	rax, qword [rdx + rax]

	mov	rax, rax			; zero-extend EAX into RAX for 64-bit indexed addressing (like movzx rax, eax)
	and	rax, r12			; rax = (fds_bits[idx] & mask)

	test	rax, rax		; rax = (fds_bits[idx] & mask) == 0
	setne	r12b			; r12b = FD_ISSET(fd, &master_fds)

	; Inputs:
	;   r12b = is_set, assumed 0 or 1
	;   fd  = fd
	;   [sender_fd]
	;   [sockfd]
	;
	; Output:
	;   r12b = hit, 0 or 1
	cmp     fd, sender_fd
	setne   al				; al = (fd != sender_fd)

	cmp     fd, sockfd
	setne   dl				; dl = (fd != sockfd)

	and     al, dl			; al &= dl
	and     r12b, al		; r12b = FD_ISSET(fd, &master_fds) && (fd != sockfd) && (fd != sender_fd)

	; if (is_set)
	test	r12b, r12b
	je	L2_loop_iter

	; -- send(fd, msg, msg_len, 0); --
	mov     ecx, 0			; flags = 0
	mov     rdx, msg_len	; size_t len
	mov     rsi, msg		; const void *buf
	mov     edi, fd			; edi = fd
	call send wrt ..plt		; Call libc function

L2_loop_iter:
	add	fd, 1
	mov	eax, [rel max_fd]
	cmp	fd, eax
	jle	L2_loop_body

L2_loop_end:
	nop
	add	rsp, 32
	pop	rbx
	pop	r12
	pop	rbp
	ret
