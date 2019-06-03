/*
 * Copyright (c) 2017 Intel Corporation
 *
 * SPDX-License-Identifier: Apache-2.0
 */

/**
 * @file
 * @brief Per-arch thread definition
 *
 * This file contains definitions for
 *
 *  struct _thread_arch
 *  struct _callee_saved
 *  struct _caller_saved
 *
 * necessary to instantiate instances of struct k_thread.
 */

#ifndef ZEPHYR_ARCH_RISCV_INCLUDE_KERNEL_ARCH_THREAD_H_
#define ZEPHYR_ARCH_RISCV_INCLUDE_KERNEL_ARCH_THREAD_H_

#ifndef _ASMLANGUAGE
#include <arch/riscv/arch.h>
#include <zephyr/types.h>

#ifndef CONFIG_SMP
/*
 * The following structure defines the list of registers that need to be
 * saved/restored when a cooperative context switch occurs.
 */
struct _callee_saved {
	_reg_t sp;       /* Stack pointer, (x2 register) */

	_reg_t s0;       /* saved register/frame pointer */
	_reg_t s1;       /* saved register */
	_reg_t s2;       /* saved register */
	_reg_t s3;       /* saved register */
	_reg_t s4;       /* saved register */
	_reg_t s5;       /* saved register */
	_reg_t s6;       /* saved register */
	_reg_t s7;       /* saved register */
	_reg_t s8;       /* saved register */
	_reg_t s9;       /* saved register */
	_reg_t s10;      /* saved register */
	_reg_t s11;      /* saved register */
};
typedef struct _callee_saved _callee_saved_t;

struct _caller_saved {
	/*
	 * Nothing here, the exception code puts all the caller-saved
	 * registers onto the stack.
	 */
};

typedef struct _caller_saved _caller_saved_t;

struct _thread_arch {
	u32_t swap_return_value; /* Return value of z_swap() */
};

typedef struct _thread_arch _thread_arch_t;

#else

struct _callee_saved {
};
typedef struct _callee_saved _callee_saved_t;

struct _caller_saved {
};
typedef struct _caller_saved _caller_saved_t;

struct _thread_arch {
};
typedef struct _thread_arch _thread_arch_t;

#endif

#endif /* _ASMLANGUAGE */

#ifdef CONFIG_SMP

/* switch handle memory content */

#define __SWITCH_HDL_s0_OFFSET			0
#define __SWITCH_HDL_s1_OFFSET			__SWITCH_HDL_s0_OFFSET 		+ RISCV_REG_SIZE
#define __SWITCH_HDL_s2_OFFSET			__SWITCH_HDL_s1_OFFSET 		+ RISCV_REG_SIZE
#define __SWITCH_HDL_s3_OFFSET			__SWITCH_HDL_s2_OFFSET 		+ RISCV_REG_SIZE
#define __SWITCH_HDL_s4_OFFSET			__SWITCH_HDL_s3_OFFSET 		+ RISCV_REG_SIZE
#define __SWITCH_HDL_s5_OFFSET			__SWITCH_HDL_s4_OFFSET 		+ RISCV_REG_SIZE
#define __SWITCH_HDL_s6_OFFSET			__SWITCH_HDL_s5_OFFSET 		+ RISCV_REG_SIZE
#define __SWITCH_HDL_s7_OFFSET			__SWITCH_HDL_s6_OFFSET 		+ RISCV_REG_SIZE
#define __SWITCH_HDL_s8_OFFSET			__SWITCH_HDL_s7_OFFSET 		+ RISCV_REG_SIZE
#define __SWITCH_HDL_s9_OFFSET			__SWITCH_HDL_s8_OFFSET 		+ RISCV_REG_SIZE
#define __SWITCH_HDL_s10_OFFSET			__SWITCH_HDL_s9_OFFSET 		+ RISCV_REG_SIZE
#define __SWITCH_HDL_s11_OFFSET			__SWITCH_HDL_s10_OFFSET 	+ RISCV_REG_SIZE
#define __SWITCH_HDL_sp_OFFSET			__SWITCH_HDL_s11_OFFSET 	+ RISCV_REG_SIZE
#define __SWITCH_HDL_max_OFFSET			(((__SWITCH_HDL_sp_OFFSET   + RISCV_REG_SIZE) + (STACK_ALIGN - 1)) & ~(STACK_ALIGN - 1))

/* sizeof cpu_init */

#define SMP_CPU_INIT_SIZE (3 * RISCV_REG_SIZE)

#endif

#endif /* ZEPHYR_ARCH_RISCV_INCLUDE_KERNEL_ARCH_THREAD_H_ */

