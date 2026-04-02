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
#include <stdio.h>
#include <arpa/inet.h>


typedef struct s_client {
	int	id;
	char	*msg;
}	t_client;


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

//	int connfd = 0;
//
//	register int FD_ELT asm("r9");
//	register int r asm("r8");
//
//	__asm__ (
//			"cdq\n\t"
//			"idiv %2"
//			: "=&a"(FD_ELT), "=&d"(r)
//			: "r"(NFDBITS), "0"(connfd)
//			: "cc"
//			);
	
//	volatile size_t sz = sizeof(t_client);
//	register size_t byte_offset asm("r13") = connfd * sz;
//	__asm__ volatile ("" : "+r"(byte_offset));

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

#define STR1(x) #x
#define STR(x) STR1(x)
#define ASM_DBG_LABEL(name) \
    asm volatile( \
        ".loc 1 " STR(__LINE__) " 0\n\t" \
        ".globl " #name "\n\t"         \
        ".hidden " #name "\n" \
        #name ":\n\t" \
        : : : "memory")
#define ASM_L(name) ASM_DBG_LABEL(name)

/* Force x to be materialized in a register here. Not a memory barrier. */
#define MATERIALIZE_IN_REG(x) __asm__ volatile ("" : "+r"(x))

/*
void handle_read(int sockfd, int fd, int bytes)
{
	char *msg_to_send = NULL;
//	t_client *client = &clients[fd];

//	escape(&client);
	int id = clients[fd].id;
	char **msg = &clients[fd].msg;
	MATERIALIZE_IN_REG(bytes);
	buf_read[bytes] = 0;

	*msg = str_join(*msg, buf_read);
	int extractResult = extract_message(msg, &msg_to_send);
	ASM_L(loop_start);
	while (extractResult != 0) {
		ASM_L(loop_body);
		const char *format = "client %d: %s";
		MATERIALIZE_IN_REG(format);
		char *bufSend = &buf_send[0];
		MATERIALIZE_IN_REG(bufSend);
		__builtin_sprintf(bufSend, format, id, msg_to_send);
		send_all(fd, sockfd, bufSend);

		free(msg_to_send);
		msg_to_send = NULL;
		extractResult = extract_message(msg, &msg_to_send);
		ASM_L(loop_iter);
	}
	ASM_L(loop_end);
}
*/

int main(int argc, char *argv[]) {

	if (argc != 2) {
		write(2, "Wrong number of arguments\n", 26);
		exit(1);
	}

	int sockfd = socket(AF_INET, SOCK_STREAM, 0);
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

	while (1) {
		read_fds = master_fds;
		int  fd_num = select(max_fd + 1, &read_fds, NULL, NULL, NULL);
		if (fd_num >= 0) {
			for (int fd = 0; fd <= max_fd; fd++) {
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
