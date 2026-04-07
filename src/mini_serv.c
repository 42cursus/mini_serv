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

// Globals
int max_fd = 0;
long next_id = 0;

t_client	clients[65536];
fd_set	master_fds = {0x00};
fd_set	read_fds;

char buf_send[1000001];
char buf_read[1000001];

void	fatal_error();
int		init(char *const argv[]);
void	send_all(int sender_fd, int sockfd, char *msg);
int		extract_message(char **buffer_pointer, char **msg);
char	*str_join(char *buf, char *add);
void	try_accept(int sockfd);
void	handle_leave(int sockfd, int fd);
void	handle_read(int sockfd, int fd, int bytes);
void	set_handlers(void);
void	sig_handler(int sig, siginfo_t *info, void *ctx);
