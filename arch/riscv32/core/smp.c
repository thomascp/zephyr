
/*
 * Copyright (c) 2019 pcheng <thomas.pcheng@gmail.com>
 *
 * SPDX-License-Identifier: Apache-2.0
 */

#include <kernel.h>
#include <kernel_structs.h>

volatile struct {
	void (*fn)(int, void*);
	void *arg;
    void *sp;
} cpu_init[CONFIG_MP_NUM_CPUS] = {0};

void z_arch_start_cpu(int cpu_num, k_thread_stack_t *stack, int sz,
		     void (*fn)(int, void *), void *arg)
{
	cpu_init[cpu_num].sp = (void *)((char *)stack + sz);

	cpu_init[cpu_num].arg = arg;

	/* This is our flag to the spinning CPU.  Do this last */
	cpu_init[cpu_num].fn = fn;
}

struct _cpu *riscv_get_curr_cpu(void)
{
	return z_arch_curr_cpu();
}


