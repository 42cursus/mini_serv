# **************************************************************************** #
#                                                                              #
#                                                         :::      ::::::::    #
#    Makefile                                           :+:      :+:    :+:    #
#                                                     +:+ +:+         +:+      #
#    By: abelov <abelov@student.42london.com>       +#+  +:+       +#+         #
#                                                 +#+#+#+#+#+   +#+            #
#    Created: 2026/03/22 23:57:50 by abelov            #+#    #+#              #
#    Updated: 2026/03/22 23:57:50 by abelov           ###   ########.fr        #
#                                                                              #
# **************************************************************************** #

export src		:= src
export bld		?= build

TARGET			= mini_serv

СС				= сс
AS				= as
NASM			= nasm
BIN_DIR			= $(bld)/bin
OBJ_DIR			= $(bld)/obj
OBJCOPY			= objcopy
OBJDUMP			= objdump

SRCS			:= mini_serv.c

ASM_SRCS		:= start.asm

OBJS		:= $(SRCS:%.c=$(BIN_DIR)/%.o)
OBJS		+= $(ASM_SRCS:%.asm=$(BIN_DIR)/%.o)

all: $(TARGET)

$(TARGET):

%: build/%.o
		@echo Target: $@
		gcc $< -o $@
		@echo

eatsyscall: build/eatsyscall.o
		@echo Target: $@
		ld -o $@ $^
		@echo

build/%.o: src/%.asm
		@echo Target: $@
		@if [ ! -d $(@D) ]; then mkdir -p $(@D); fi
		nasm -f elf64 -g -F dwarf $< -o $@
		@echo

## clean
clean:
		@echo Target: $@
		@$(RM) -rfv $(OBJS)
		@echo

## fclean
fclean: clean
		@echo Target: $@
		@$(RM) -vf $(NAMES)
		@echo

re: fclean
		+@$(MAKE) all --no-print-directory

.SECONDARY: $(OBJS)
.PHONY: all clean fclean re
