/*
 * Copyright (c) 2016 Jean-Paul Etienne <fractalclone@gmail.com>
 *
 * SPDX-License-Identifier: Apache-2.0
 */

/**
 * @file
 * @brief Private kernel definitions
 *
 * This file contains private kernel function/macro definitions and various
 * other definitions for the RISCV32 processor architecture.
 */

#ifndef ZEPHYR_ARCH_RISCV32_INCLUDE_KERNEL_ARCH_FUNC_H_
#define ZEPHYR_ARCH_RISCV32_INCLUDE_KERNEL_ARCH_FUNC_H_

#include <soc.h>

#ifdef __cplusplus
extern "C" {
#endif

#ifndef _ASMLANGUAGE
void k_cpu_idle(void);
void k_cpu_atomic_idle(unsigned int key);

static ALWAYS_INLINE void kernel_arch_init(void)
{
	_kernel.cpus[0].irq_stack =
		Z_THREAD_STACK_BUFFER(_interrupt_stack) + CONFIG_ISR_STACK_SIZE;
}

#ifndef CONFIG_SMP

static ALWAYS_INLINE void
z_set_thread_return_value(struct k_thread *thread, unsigned int value)
{
	thread->arch.swap_return_value = value;
}

#define z_is_in_isr() (_kernel.nested != 0U)

#endif

FUNC_NORETURN void z_NanoFatalErrorHandler(unsigned int reason,
					  const NANO_ESF *esf);

#ifdef CONFIG_IRQ_OFFLOAD
int z_irq_do_offload(void);
#endif

#ifdef CONFIG_SMP

#define z_is_in_isr() (z_arch_curr_cpu()->nested != 0)

void z_arch_switch(void *switch_to, void **switched_from);

static inline struct _cpu *z_arch_curr_cpu(void)
{
	unsigned long cpuid;

	__asm__ volatile("csrr %0, mhartid" : "=r"(cpuid));

	return &_kernel.cpus[cpuid];
}

#endif

#endif /* _ASMLANGUAGE */

#ifdef __cplusplus
}
#endif

#endif /* ZEPHYR_ARCH_RISCV32_INCLUDE_KERNEL_ARCH_FUNC_H_ */
