/* ************************************************************************** */
/*                                                                            */
/*                                                        :::      ::::::::   */
/*   mini_serv.c                                        :+:      :+:    :+:   */
/*                                                    +:+ +:+         +:+     */
/*   By: abelov <abelov@student.42london.com>       +#+  +:+       +#+        */
/*                                                +#+#+#+#+#+   +#+           */
/*   Created: 2026/03/22 23:23:45 by abelov            #+#    #+#             */
/*   Updated: 2026/03/22 23:23:45 by abelov           ###   ########.fr       */
/*                                                                            */
/* ************************************************************************** */

#define _GNU_SOURCE         /* See feature_test_macros(7) */
#undef _FORTIFY_SOURCE
#define _FORTIFY_SOURCE 0
#include <string.h>
#include <unistd.h>
#include <sys/socket.h>
#include <netinet/in.h>
#include <stdlib.h>
#include <arpa/inet.h>
#include <signal.h>


typedef struct s_client {
	int	id;
	char	*msg;
}	t_client;

sig_atomic_t g_var = {0x00};
typedef struct sigaction t_sigaction;

// Globals
int max_fd = 0;
long next_id = 0;

t_client	clients[65536];
fd_set	master_fds = {0x00};
fd_set	read_fds;

char buf_send[1000001];
char buf_read[1000001];

//__attribute__((noreturn, cold)) void	fatal_error(void);
void	fatal_error();
int		init(char *const argv[]);
void	send_all(int sender_fd, int sockfd, char *msg);
int		extract_message(char **bufferPointer, char **msg);
char	*str_join(char *buf, char *add);
void	try_accept(int sockfd);
void	handle_leave(int sockfd, int fd);
void	handle_read(int sockfd, int fd, int bytes);

/*
__attribute__((noinline,optimize("-O0")))
static void escape(void *p) { asm volatile("" : : "g"(p) : "memory"); }
*/

#define STR1(x) #x
#define STR(x) STR1(x)
#define ASM_DBG_LABEL(name) \
    asm volatile( \
        ".loc 1 " STR(__LINE__) " 0\n\t" \
        ".globl " #name "\n\t"	\
    	".hidden " #name "\n"	\
        /*                    	\
         ".globl " #name "\n"	\
    	*/                     	\
        #name ":\n\t" \
        : : : "memory")
#define ASM_L(name) ASM_DBG_LABEL(name)

/* Force x to be materialized in a register here. Not a memory barrier. */
#define MATERIALIZE_IN_REG(x) __asm__ volatile ("" : "+r"(x))

__attribute__((noinline,optimize("-O0")))
static void escape(void *p) {
	asm volatile("" : : "g"(p) : "memory");
}

__attribute__((__noinline__))
void sig_handler(int sig, siginfo_t *info, void *ctx) {
	int sipid = info->si_pid;
	if (sig == SIGINT)
		g_var = SIGINT;
	return;
	(void)ctx;
	(void)sipid;
}

void set_handlers() {
	t_sigaction act;
	t_sigaction old_act;

	act.sa_flags	 = SA_SIGINFO;// Do NOT set SA_RESTART; we want syscalls to be interrupted.
	act.sa_sigaction = &sig_handler;
	sigemptyset(&act.sa_mask);
	if (sigaction(SIGINT, &act, &old_act) != 0)
		exit(EXIT_FAILURE);
}

int init2(in_addr_t s_addr, in_port_t prt);

int init2(in_addr_t s_addr, in_port_t prt) {
	struct sockaddr_in addr;

	addr.sin_family = AF_INET;
	addr.sin_port = prt;
	addr.sin_addr.s_addr = s_addr;
	memset(addr.sin_zero, 0, sizeof addr.sin_zero);

	set_handlers();
	int sockfd = socket(AF_INET, SOCK_STREAM, IPPROTO_TCP);

	if (sockfd < 0) goto fail;

ASM_L(pass1);
	int reuse = 1;
	int result = setsockopt(sockfd, SOL_SOCKET, SO_REUSEADDR, (void *)&reuse, sizeof(reuse));
	if (result < 0) goto fail;

ASM_L(pass2);
	FD_ZERO(&master_fds);
	register __fd_mask *fds_bits asm("r12") = (__fd_mask *) &master_fds.fds_bits;
	memset(fds_bits, 0, sizeof(__fd_mask) * (FD_SETSIZE / NFDBITS));
	max_fd = sockfd;

	// FD_SET(sockfd, &master_fds);
	__fd_mask mask = __FD_MASK(sockfd);
	int idx = __FD_ELT(sockfd);
	(void)(master_fds.fds_bits[idx] |= mask);

	int bindStatus = bind(sockfd, (const struct sockaddr *) &addr, sizeof(addr));

	if (bindStatus < 0) goto fail;

ASM_L(pass3);
	int listenFdStatus = listen(sockfd, 128);
	if (listenFdStatus < 0) goto fail;

ASM_L(pass4);
	return (sockfd);
fail:
	ASM_L(fail);
	fatal_error();
	__builtin_trap(); // or	__builtin_unreachable();
}
