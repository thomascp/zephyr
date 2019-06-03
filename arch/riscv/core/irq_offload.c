/*
 * Copyright (c) 2016 Jean-Paul Etienne <fractalclone@gmail.com>
 *
 * SPDX-License-Identifier: Apache-2.0
 */

#include <irq.h>
#include <irq_offload.h>
#include <misc/printk.h>
#include <kernel_structs.h>

volatile irq_offload_routine_t _offload_routine[CONFIG_MP_NUM_CPUS];
static volatile void *offload_param[CONFIG_MP_NUM_CPUS];

/*
 * Called by _enter_irq
 *
 * Just in case the offload routine itself generates an unhandled
 * exception, clear the offload_routine global before executing.
 */
void z_irq_do_offload(void)
{
	irq_offload_routine_t tmp;
	unsigned int cpuid = z_arch_curr_cpu()->id;

	if (!_offload_routine[cpuid])
		return;

	tmp = _offload_routine[cpuid];
	_offload_routine[cpuid] = NULL;

	tmp((void *)offload_param[cpuid]);
}

irq_offload_routine_t z_irq_get_offload(void)
{
	unsigned int cpuid = z_arch_curr_cpu()->id;

	return _offload_routine[cpuid];
}

void irq_offload(irq_offload_routine_t routine, void *parameter)
{
	unsigned int key;
	unsigned int cpuid = z_arch_curr_cpu()->id;

	key = irq_lock();
	_offload_routine[cpuid] = routine;
	offload_param[cpuid] = parameter;

	__asm__ volatile ("ecall");

	irq_unlock(key);
}
