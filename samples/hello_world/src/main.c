/*
 * Copyright (c) 2017 Linaro Limited
 *
 * SPDX-License-Identifier: Apache-2.0
 */

#include <zephyr.h>
#include <device.h>
#include <misc/printk.h>
#include <misc/__assert.h>
#include <string.h>
#include <kernel_structs.h>

/* size of stack area used by each thread */
#define STACKSIZE 1024

/* scheduling priority used by each thread */
#define PRIORITY 7

void blink1(void)
{
	while(1)
	{
		printk ("thread 1 %d\n", _current_cpu->id);
		k_sleep(5000);
	}
}

void blink2(void)
{
	while(1)
	{
		printk ("thread 2 %d\n", _current_cpu->id);
		k_sleep(10000);
	}
}

struct k_thread thread1;
struct k_thread thread2;
static K_THREAD_STACK_DEFINE(tstack1, STACKSIZE);
static K_THREAD_STACK_DEFINE(tstack2, STACKSIZE);

void main()
{
	k_tid_t thread;

	thread = k_thread_create(&thread1,
					 tstack1, STACKSIZE,
					 blink1, NULL, NULL, NULL,
					 PRIORITY,
					 0, K_FOREVER);
	k_thread_cpu_mask_clear(thread);
	k_thread_cpu_mask_enable(thread, 0);
	k_thread_start(thread);

	thread = k_thread_create(&thread2,
					 tstack2, STACKSIZE,
					 blink2, NULL, NULL, NULL,
					 PRIORITY,
					 0, K_FOREVER);
	k_thread_cpu_mask_clear(thread);
	k_thread_cpu_mask_enable(thread, 1);
	k_thread_start(thread);
}
