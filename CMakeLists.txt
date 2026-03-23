# **************************************************************************** #
#                                                                              #
#                                                         :::      ::::::::    #
#    CMakeLists.txt                                     :+:      :+:    :+:    #
#                                                     +:+ +:+         +:+      #
#    By: abelov <abelov@student.42london.com>       +#+  +:+       +#+         #
#                                                 +#+#+#+#+#+   +#+            #
#    Created: 2026/03/19 17:27:11 by abelov            #+#    #+#              #
#    Updated: 2026/03/19 17:27:11 by abelov           ###   ########.fr        #
#                                                                              #
# **************************************************************************** #

cmake_minimum_required(VERSION 3.18)

include_directories("include")

project("mini_serv" VERSION 0.1.0 LANGUAGES C CXX ASM ASM_NASM)

set(CMAKE_C_STANDARD 11)

set(TARGET_EXE_NAME "${PROJECT_NAME}")

set(PROJECT_CFLAGS -g3 -O0 -mmanual-endbr)
set(NASM_FLAGS -f elf64 -g -F dwarf -Wall -w-reloc-rel-dword)

set(TARGET_CFLAGS ${PROJECT_CFLAGS})
set(TARGET_ASM_FLAGS ${NASM_FLAGS})

file(GLOB TARGET_HEADERS "src/*.h")
set(GLOB TARGET_SOURCES)
file(GLOB TARGET_ASM_SOURCES "src/*.asm")
file(GLOB TARGET_C_SOURCES "src/*.c")
file(GLOB TARGET_ASM2_SOURCES "src2/*.asm")
file(GLOB TARGET_C2_SOURCES "src2/*.c")
list(APPEND TARGET_SOURCES "${TARGET_ASM2_SOURCES};${TARGET_C2_SOURCES}")
list(APPEND TARGET_SOURCES "${TARGET_ASM_SOURCES};${TARGET_C_SOURCES}")

add_executable(${TARGET_EXE_NAME} ${TARGET_HEADERS} ${TARGET_SOURCES})

target_link_options(${TARGET_EXE_NAME} PRIVATE)
target_link_options(${TARGET_EXE_NAME}
        PRIVATE
        -O0 -g3
        -Wa,-L
        -fno-omit-frame-pointer
        -gdwarf-3
        -nostartfiles
)

target_compile_options(${TARGET_EXE_NAME}
        PRIVATE
        $<$<COMPILE_LANGUAGE:ASM_NASM>:
        ${TARGET_ASM_FLAGS}>
        $<$<COMPILE_LANGUAGE:C>:
        ${TARGET_CFLAGS}>)

set_target_properties(${TARGET_EXE_NAME} PROPERTIES
        LINKER_LANGUAGE "C"
        RUNTIME_OUTPUT_DIRECTORY "${PROJECT_SOURCE_DIR}"
        OUTPUT_NAME "${TARGET_EXE_NAME}")