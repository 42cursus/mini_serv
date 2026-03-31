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
	sprintf(buf_send, "server: client %d just left\n", clients[fd].id);
	send_all(fd, sockfd, buf_send);

	FD_CLR(fd, &master_fds);
	close(fd);

	if (clients[fd].msg == NULL) goto clear;
		free(clients[fd].msg);
clear:
	clients[fd].msg = NULL;
}
*/


void handle_read(int sockfd, int fd, int bytes) {
	buf_read[bytes] = 0;
	clients[fd].msg = str_join(clients[fd].msg, buf_read);

	char *msg_to_send = NULL;
	while (extract_message(&clients[fd].msg, &msg_to_send) != 0) {

		sprintf(buf_send, "client %d: %s", clients[fd].id, msg_to_send);
		send_all(fd, sockfd, buf_send);

		free(msg_to_send);
		msg_to_send = NULL;
	}
}

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
