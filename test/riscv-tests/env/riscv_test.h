#ifndef _RISCV_TEST_H
#define _RISCV_TEST_H

#define RVTEST_RV32U
#define RVTEST_RV64U

#define TESTNUM gp

#define RVTEST_CODE_BEGIN                                               \
        .section .text.init;                                            \
        .align 4;                                                       \
        .globl _start;                                                  \
_start:                                                                 \
        li x1, 0;                                                       \
        li x2, 0;                                                       \
        li x3, 0;                                                       \
        li x4, 0;                                                       \
        li x5, 0;                                                       \
        li x6, 0;                                                       \
        li x7, 0;                                                       \
        li x8, 0;                                                       \
        li x9, 0;                                                       \
        li x10, 0;                                                      \
        li x11, 0;                                                      \
        li x12, 0;                                                      \
        li x13, 0;                                                      \
        li x14, 0;                                                      \
        li x15, 0;                                                      \
        li x16, 0;                                                      \
        li x17, 0;                                                      \
        li x18, 0;                                                      \
        li x19, 0;                                                      \
        li x20, 0;                                                      \
        li x21, 0;                                                      \
        li x22, 0;                                                      \
        li x23, 0;                                                      \
        li x24, 0;                                                      \
        li x25, 0;                                                      \
        li x26, 0;                                                      \
        li x27, 0;                                                      \
        li x28, 0;                                                      \
        li x29, 0;                                                      \
        li x30, 0;                                                      \
        li x31, 0;                                                      \
        li TESTNUM, 0;

#define RVTEST_CODE_END                                                 \
        nop;

#define RVTEST_PASS                                                     \
        li TESTNUM, 1;                                                  \
pass_loop:                                                              \
        j pass_loop;

#define RVTEST_FAIL                                                     \
        sll TESTNUM, TESTNUM, 1;                                        \
        or  TESTNUM, TESTNUM, 1;                                        \
fail_loop:                                                              \
        j fail_loop;

#define RVTEST_DATA_BEGIN                                               \
        .section .data;                                                 \
        .align 4;                                                       \
        .globl tohost;                                                  \
tohost: .word 0;                                                        \
        .globl fromhost;                                                \
fromhost: .word 0;

#define RVTEST_DATA_END                                                 \
        .align 4;

#endif
