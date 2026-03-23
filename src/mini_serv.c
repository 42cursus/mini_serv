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

void fatal_error() {
	char *err = "Fatal error\n";
	write(STDERR_FILENO, err, strlen(err));
	exit(EXIT_FAILURE);
}

void send_all(int sender_fd, int sockfd, char *msg) {
	for (int fd = 0; fd <= max_fd; fd++) {
		if (FD_ISSET(fd, &master_fds) && fd != sender_fd && fd != sockfd)
			send(fd, msg, strlen(msg), 0);
	}
}

char	*str_join(char *buf, char *add) {
	char	*new_buf;
	int		len;

	len = 0;
	if (buf != NULL)
		len = strlen(buf);
	new_buf = malloc((len + strlen(add) + 1) * sizeof(char));
	if (new_buf == NULL)
		return (NULL);
	new_buf[0] = '\0';
	if (buf != NULL)
		strcat(new_buf, buf);
	free(buf);
	strcat(new_buf, add);
	return (new_buf);
}

int	extract_message(char **buf, char **msg) {
	char	*new_buf;
	int		i;

	*msg = 0;
	if (*buf == 0)
		return (0);
	i = 0;
	while ((*buf)[i]) {
		if ((*buf)[i] == '\n') {
			new_buf = calloc(1, sizeof(*new_buf) * (strlen(*buf + i + 1) + 1));
			if (new_buf == 0)
				return (-1);
			strcpy(new_buf, *buf + i + 1);
			*msg = *buf;
			(*msg)[i + 1] = 0;
			*buf = new_buf;
			return (1);
		}
		i++;
	}
	return (0);
}

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
