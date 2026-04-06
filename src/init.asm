; init.asm
BITS 64

default rel

; #include <arpa/inet.h>
; #include <netinet/in.h>
%assign IPPROTO_IP			0 ; Dummy protocol for TCP.
%assign IPPROTO_TCP			6 ; Transmission Control Protocol.
%assign IPPROTO_UDP			17	; User Datagram Protocol.

; #include <sys/socket.h>
%assign SO_REUSEADDR		2
%assign PF_INET				2 ; IP protocol family.
%assign AF_INET				2 ;

; #include <bits/socket_type.h>
%assign SOL_SOCKET			1
%assign SOCK_STREAM			1 ; Sequenced, reliable, connection-based byte streams.

%assign sizeof_int			4
%assign sizeof_t_client		16 ;
%assign sizeof_fd_set		0x80 ; 128 == FD_SETSIZE / NFDBITS
%assign sizeof_sockaddr_in	16 ;

SECTION .bss              ; Section containing uninitialized data

extern max_fd
extern master_fds

SECTION .text
..@text_pad:
    nop

extern memset
extern socket
extern bind
extern listen
extern setsockopt
extern set_handlers
extern fatal_error

global init:function (init.end - init)

init:
	push	rbp
	mov	rbp, rsp
	push	r12
	push	rbx
	sub	rsp, 32

	%assign reuse_off							36 ;
	%define reuse								dword[rbp - reuse_off] ; DWORD PTR -36[rbp]

	%assign addr_off							32 ;
	%assign sin_family_off						0 ;
	%assign sin_port_off						2 ;
	%assign sin_addr_off						4 ;
	%assign sin_zero_off						8 ;

	%define addr__sin_family					word[rbp - addr_off + sin_family_off] ; WORD PTR -32[rbp]
	%define addr__sin_port						word[rbp - addr_off + sin_port_off] ; WORD PTR -30[rbp]
	%define addr__sin_addr__s_addr				dword[rbp - addr_off + sin_addr_off + 0] ; DWORD PTR -28[rbp]
	%define addr__sin_zero						qword[rbp - addr_off + sin_zero_off] ; QWORD PTR -24[rbp]

	; struct sockaddr_in addr;
	mov	addr__sin_family, AF_INET				; addr.sin_family = AF_INET;
	mov	addr__sin_port, si						; addr.sin_port = prt;
	mov	addr__sin_addr__s_addr, edi				; addr.sin_addr.s_addr = s_addr;
	mov	addr__sin_zero, 0						; memset(addr.sin_zero, 0, sizeof addr.sin_zero);

	; set_handlers();
	mov	eax, 0
	call	set_handlers wrt ..plt

	; int sockfd = socket(AF_INET, SOCK_STREAM, IPPROTO_TCP);
	mov	edx, IPPROTO_TCP
	mov	esi, SOCK_STREAM
	mov	edi, AF_INET
	call	socket wrt ..plt
	mov	ebx, eax								; ebx now holds sockfd

	; if (sockfd < 0) goto fail;
	test	eax, eax
	js	.fail

.pass1:
	; int reuse = 1;
	mov	reuse, 1

	; int result = setsockopt(sockfd, SOL_SOCKET, SO_REUSEADDR, (void *)&reuse, sizeof(reuse));
	mov	r8d, sizeof_int
	lea	rcx, [rbp - reuse_off]
	mov	edx, SO_REUSEADDR
	mov	esi, SOL_SOCKET
	mov	edi, ebx
	call	setsockopt wrt ..plt

	; if (result < 0) goto fail;
	test	eax, eax
	js	.fail

.pass2:
	; register __fd_mask *fds_bits asm("r12") = (__fd_mask *) &master_fds.fds_bits;
	lea	r12, [rel master_fds]

	; FD_ZERO(&master_fds);
	mov	edx, sizeof_fd_set
	mov	esi, 0
	mov	rdi, r12
	call	memset wrt ..plt

	; max_fd = sockfd;
	mov	dword [rel max_fd], ebx

	; __fd_mask mask = __FD_MASK(sockfd);
	mov	eax, 1
	mov	ecx, ebx
	sal	rax, cl
	mov	rdx, rax

	; int idx = __FD_ELT(sockfd);
	lea	eax, [rbx + 63]
	test	ebx, ebx
	cmovns	eax, ebx
	sar	eax, 6
	cdqe

	; (void)(master_fds.fds_bits[idx] |= mask);
	mov	qword [r12 + rax * 8], rdx

	; register int bindStatus = bind(sockfd, (const struct sockaddr *) &addr, sizeof(addr));
	mov	edx, sizeof_sockaddr_in					; socklen_t addrlen = sizeof(addr)
	lea	rsi, [rbp - addr_off]					; const struct sockaddr *addr = (const struct sockaddr *) &addr
	mov	edi, ebx								; int sockfd = sockfd
	call	bind wrt ..plt

	; if (bindStatus < 0) goto fail;
	test	eax, eax
	js	.fail

.pass3:
	; register int listenFdStatus = listen(sockfd, 128);
	mov	esi, 128
	mov	edi, ebx
	call	listen wrt ..plt

	; if (listenFdStatus < 0) goto fail;
	test	eax, eax
	jns	.good

.fail:
	mov	eax, 0
	call	fatal_error wrt ..plt
	ud2											; __builtin_trap(); // or	__builtin_unreachable();

.good:
	mov	eax, ebx
	add	rsp, 32
	pop	rbx
	pop	r12
	pop	rbp
	ret
.end:
