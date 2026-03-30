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
#include <string.h>
#include <unistd.h>
#include <sys/socket.h>
#include <netinet/in.h>
#include <stdlib.h>
#include <stdio.h>

// Globals
int max_fd = 0;
int next_id = 0;

typedef struct s_client {
	int		id;
	char	*msg;
}	t_client;

t_client	clients[65536];

fd_set	master_fds;
fd_set	read_fds;

char buf_send[1000001];
char buf_read[1000001];

void	fatal_error();
void	send_all(int sender_fd, int sockfd, char *msg);
int		extract_message(char **bufferPointer, char **msg);

/*
#define STR1(x) #x
#define STR(x) STR1(x)
#define ASM_DBG_LABEL(name) \
    asm volatile( \
        ".loc 1 " STR(__LINE__) " 0\n\t" \
        ".globl " #name "\n\t"         \
        ".hidden " #name "\n\t" \
        #name ":\n\t" \
        : : : "memory")
#define ASM_L(name) ASM_DBG_LABEL(name)

void send_all2(int sender_fd, int sockfd, char *msg)
{
	__fd_mask *fds_bits = master_fds.fds_bits;

	for (int fd = 0; fd <= max_fd; fd++) {
		volatile unsigned int i = __NFDBITS;
		unsigned int rem = (fd) % i;
		__fd_mask mask = (__fd_mask) (1UL << rem);
		int idx = (fd) / i;
		__fd_mask bits = fds_bits[idx];
		register _Bool is_set = (bits & mask) != 0;
		register _Bool hit = is_set & (fd != sender_fd) & (fd != sockfd);
		if (hit)
			send(fd, msg, strlen(msg), 0);
	}
}


void send_all3(int sender_fd, int sockfd, char *msg) {
	__fd_mask *fds_bits = NULL;
	size_t msg_len = 0;

	register size_t msg_len_r = strlen(msg);

	msg_len = msg_len_r;
	fds_bits = master_fds.fds_bits;

	// Enter a loop for processing sending messages
	register int fd = 0;


	goto loop_iter;
loop_start:
	ASM_L(send_loop_start);

	register unsigned int i = __NFDBITS;

	register unsigned int idx = (fd) / i;

	unsigned int i1 = (fd) % i;
	register __fd_mask i2 = fds_bits[idx];
	register __fd_mask mask = (__fd_mask) (1UL << i1);

	register _Bool is_set = (i2 & mask) != 0;
//	register _Bool is_set = (fds_bits[(fd) / i] & mask) != 0;
//	register _Bool is_set = (master_fds.fds_bits[idx] & mask) != 0;

//	register _Bool is_set = FD_ISSET(fd, &master_fds);

	register _Bool hit = is_set & (fd != sender_fd) & (fd != sockfd);
	if (hit)
		send(fd, msg, msg_len, 0);

	fd++;
	ASM_L(send_loop_iter);
loop_iter:
	if (fd <= max_fd)
		goto loop_start;
	ASM_L(send_loop_end);
}
*/

char	*str_join(char *buf, char *add);

/*
__attribute__((noinline,optimize("-O0")))
static void escape(void *p) { asm volatile("" : : "g"(p) : "memory"); }


char	*str_join(char *buf, char *add) {
	const char *p = buf ? buf : "";
	size_t len = strlen(p);
	char *new_buf = malloc((len + strlen(add) + 1) * sizeof(char));
	escape(&new_buf);
	if (new_buf != NULL) goto result;
	new_buf[0] = '\0';
	strcat(new_buf, p);
	free(buf);
	strcat(new_buf, add);
result:
	return (new_buf);
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

	max_fd = sockfd;
	FD_ZERO(&master_fds);
	FD_SET(sockfd, &master_fds);

	struct sockaddr_in addr;
	bzero(&addr, sizeof(addr));
	addr.sin_family = AF_INET;
	addr.sin_addr.s_addr = htonl(2130706433); // 127.0.0.1
	addr.sin_port = htons(atoi(argv[1]));

	if (bind(sockfd, (const struct sockaddr *) &addr, sizeof(addr)) < 0)
		fatal_error();
	if (listen(sockfd, 128) < 0)
		fatal_error();

	while (1) {

		read_fds = master_fds;

		if (select(max_fd + 1, &read_fds, NULL, NULL, NULL) < 0)
			continue;

		for (int fd = 0; fd <= max_fd; fd++) {

			if (!FD_ISSET(fd, &read_fds))
				continue;

			if (fd == sockfd) {
				struct sockaddr_in client_addr;
				socklen_t len = sizeof(client_addr);

				int connfd = accept(sockfd, (struct sockaddr *)&client_addr, &len);

				if (connfd < 0)
					continue;

				max_fd = (connfd > max_fd) ? connfd : max_fd;

				clients[connfd].id = next_id++;
				clients[connfd].msg = NULL;

				FD_SET(connfd, &master_fds);

				sprintf(buf_send, "server: client %d just arrived\n", clients[connfd].id);
				send_all(connfd, sockfd, buf_send);

			} else {

				int bytes = recv(fd, buf_read, 8192, 0);

				if (bytes <= 0) {

					sprintf(buf_send, "server: client %d just left\n", clients[fd].id);
					send_all(fd, sockfd, buf_send);

					FD_CLR(fd, &master_fds);
					close(fd);

					if (clients[fd].msg)
						free(clients[fd].msg);
					clients[fd].msg = NULL;

				} else {
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
			}
		}
	}
	return 0;
}
