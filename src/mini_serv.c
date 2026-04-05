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
fd_set	master_fds;
fd_set	read_fds;

char buf_send[1000001];
char buf_read[1000001];

void	fatal_error();
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

__attribute__((noinline,optimize("-O0")))
static void escape(void *p) {
	asm volatile("" : : "g"(p) : "memory");
}

/*
void handle_leave(int sockfd, int fd) {
	const char *string = "server: client %d just left\n";
	__builtin_sprintf(buf_send, string, clients[fd].id);
	send_all(fd, sockfd, buf_send);

	FD_CLR(fd, &master_fds);
	close(fd);

	if (clients[fd].msg == NULL) goto clear;
		free(clients[fd].msg);
clear:
	clients[fd].msg = NULL;
}
*/

void sig_handler(int sig, siginfo_t *info, void *ctx) {
	int sipid = info->si_pid;
	if (sig == SIGINT)
		g_var = SIGINT;
	// std::cout << "\e[1k" << std::endl;
	return;
	(void)ctx;
	(void)sipid;
}

#define STR1(x) #x
#define STR(x) STR1(x)
#define ASM_DBG_LABEL(name) \
    asm volatile( \
        ".loc 1 " STR(__LINE__) " 0\n\t" \
        /*                    	\
        ".globl " #name "\n\t"	\
    	".hidden " #name "\n"	\
    	*/                     	\
         ".globl " #name "\n"	\
        #name ":\n\t" \
        : : : "memory")
#define ASM_L(name) ASM_DBG_LABEL(name)

/* Force x to be materialized in a register here. Not a memory barrier. */
#define MATERIALIZE_IN_REG(x) __asm__ volatile ("" : "+r"(x))

void set_handlers() {
	t_sigaction act;
	t_sigaction old_act;

	act.sa_flags	 = SA_SIGINFO;// Do NOT set SA_RESTART; we want syscalls to be interrupted.
	act.sa_sigaction = &sig_handler;
	sigemptyset(&act.sa_mask);
	if (sigaction(SIGINT, &act, &old_act) != 0)
		exit(EXIT_FAILURE);
}

int init(char *const argv[]) {

	set_handlers();

	int sockfd = socket(AF_INET, SOCK_STREAM, 0);
	MATERIALIZE_IN_REG(sockfd);

	escape(&argv);

	if (sockfd < 0)
		fatal_error();

	int reuse = 1;
	int result = setsockopt(sockfd, SOL_SOCKET, SO_REUSEADDR, (void *)&reuse, sizeof(reuse));
	if (result < 0)
		fatal_error();

	max_fd = sockfd;
	FD_ZERO(&master_fds);
	FD_SET(sockfd, &master_fds);

	struct sockaddr_in addr;
	bzero(&addr, sizeof(addr));
	addr.sin_family = AF_INET;
	addr.sin_addr.s_addr = htonl(INADDR_LOOPBACK); // 127.0.0.1; 2130706433
	addr.sin_addr.s_addr = inet_addr("127.0.0.1");
	inet_pton(addr.sin_family, "127.0.0.1", &addr.sin_addr);
	addr.sin_port = htons(atoi(argv[1]));

	if (bind(sockfd, (const struct sockaddr *) &addr, sizeof(addr)) < 0)
		fatal_error();
	if (listen(sockfd, 128) < 0)
		fatal_error();
	return sockfd;
}

int main(register int argc_r, register char *argv_r[]);
/*
int main(register int argc_r, register char *argv_r[]) {
	// https://gcc.gnu.org/onlinedocs/gcc/Local-Register-Variables.html
	register int argc asm("r13") = argc_r;
	MATERIALIZE_IN_REG(argc);
	register char **argv asm("r14") = argv_r;
	MATERIALIZE_IN_REG(argv);

	if (argc != 2)
	{
		write(2, "Wrong number of arguments\n", 26);
		exit(EXIT_FAILURE);
	}

	extern sig_atomic_t				g_var;
	int sockfd = init(argv);
	ASM_L(even_loop_start);
	while(g_var != SIGINT) {
		ASM_L(even_loop_body);
//		__builtin_memcpy(&read_fds, &master_fds, sizeof(fd_set));
		read_fds = master_fds;
//		*(volatile fd_set*)&read_fds = *(volatile fd_set*)&master_fds;
		__asm__ __volatile__("" : : : "memory");
//		memcpy(&read_fds, &master_fds, sizeof(master_fds));
		int  fd_num = select(max_fd + 1, &read_fds, NULL, NULL, NULL);
		if (fd_num >= 0) {
			ASM_L(fd_loop_start);
			int fd = -1;
			while (++fd <= max_fd) {
				ASM_L(fd_loop_body);
				register _Bool is_set = FD_ISSET(fd, &read_fds);
				MATERIALIZE_IN_REG(is_set);
				if (is_set) {
					ASM_L(fd_is_set_test);
					if (fd == sockfd) {
						ASM_L(fd_eq_sockfd_body);
						try_accept(sockfd);
					} else {
						ASM_L(fd_neq_sockfd_body);
						int bytes = recv(fd, buf_read, 8192, 0);
						if (bytes <= 0) {
							ASM_L(bytes_recv_lt_zero);
							handle_leave(sockfd, fd);
						} else {
							ASM_L(bytes_recv_gt_zero);
							handle_read(sockfd, fd, bytes);
						}
					}
				}
				ASM_L(fd_is_not_set);
				ASM_L(fd_loop_iter);
			}
			ASM_L(fd_loop_end);
		}
		ASM_L(even_loop_iter);
	}
	ASM_L(even_loop_end);
	return 0;
}
*/

int main2(register int argc_r, register char *argv_r[]) {
	// https://gcc.gnu.org/onlinedocs/gcc/Local-Register-Variables.html
	register int argc = argc_r;
	MATERIALIZE_IN_REG(argc);
	register char **argv = argv_r;
	MATERIALIZE_IN_REG(argv);

	if (argc != 2)
	{
		write(2, "Wrong number of arguments\n", 26);
		exit(EXIT_FAILURE);
	}
	extern sig_atomic_t				g_var;
	int sockfd = init(argv);

	while(g_var != SIGINT) {
		memcpy(&read_fds, &master_fds, sizeof(fd_set));
		int  fd_num = select(max_fd + 1, &read_fds, NULL, NULL, NULL);
		if (fd_num >= 0) {
			int fd = -1;
			while (++fd <= max_fd) {
				if (FD_ISSET(fd, &read_fds)) {
					if (fd == sockfd)
						try_accept(sockfd);
					else {
						int bytes = recv(fd, buf_read, 8192, 0);
						if (bytes <= 0) handle_leave(sockfd, fd);
						else handle_read(sockfd, fd, bytes);
					}
				}
			}
		}
	}
	return 0;
}
