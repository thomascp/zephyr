/*
 * Copyright (c) 2016 Jean-Paul Etienne <fractalclone@gmail.com>
 *
 * SPDX-License-Identifier: Apache-2.0
 */

#include <irq.h>
#include <kernel_structs.h>
#include <offsets_short.h>

/* exports */
#ifndef CONFIG_SMP
GTEXT(__swap)
#else
GTEXT(z_arch_switch)
#endif
GTEXT(z_thread_entry_wrapper)

/* Use ABI name of registers for the sake of simplicity */

#ifndef CONFIG_SMP
/*
 * unsigned int __swap(unsigned int key)
 *
 * Always called with interrupts locked
 * key is stored in a0 register
 */
SECTION_FUNC(exception.other, __swap)

	/* Make a system call to perform context switch */
#ifdef CONFIG_EXECUTION_BENCHMARKING
	addi sp, sp, -__NANO_ESF_SIZEOF

	sw ra, __NANO_ESF_ra_OFFSET(sp)
	sw gp, __NANO_ESF_gp_OFFSET(sp)
	sw tp, __NANO_ESF_tp_OFFSET(sp)
	sw t0, __NANO_ESF_t0_OFFSET(sp)
	sw t1, __NANO_ESF_t1_OFFSET(sp)
	sw t2, __NANO_ESF_t2_OFFSET(sp)
	sw t3, __NANO_ESF_t3_OFFSET(sp)
	sw t4, __NANO_ESF_t4_OFFSET(sp)
	sw t5, __NANO_ESF_t5_OFFSET(sp)
	sw t6, __NANO_ESF_t6_OFFSET(sp)
	sw a0, __NANO_ESF_a0_OFFSET(sp)
	sw a1, __NANO_ESF_a1_OFFSET(sp)
	sw a2, __NANO_ESF_a2_OFFSET(sp)
	sw a3, __NANO_ESF_a3_OFFSET(sp)
	sw a4, __NANO_ESF_a4_OFFSET(sp)
	sw a5, __NANO_ESF_a5_OFFSET(sp)
	sw a6, __NANO_ESF_a6_OFFSET(sp)
	sw a7, __NANO_ESF_a7_OFFSET(sp)

	call read_timer_start_of_swap

	lw ra, __NANO_ESF_ra_OFFSET(sp)
	lw gp, __NANO_ESF_gp_OFFSET(sp)
	lw tp, __NANO_ESF_tp_OFFSET(sp)
	lw t0, __NANO_ESF_t0_OFFSET(sp)
	lw t1, __NANO_ESF_t1_OFFSET(sp)
	lw t2, __NANO_ESF_t2_OFFSET(sp)
	lw t3, __NANO_ESF_t3_OFFSET(sp)
	lw t4, __NANO_ESF_t4_OFFSET(sp)
	lw t5, __NANO_ESF_t5_OFFSET(sp)
	lw t6, __NANO_ESF_t6_OFFSET(sp)
	lw a0, __NANO_ESF_a0_OFFSET(sp)
	lw a1, __NANO_ESF_a1_OFFSET(sp)
	lw a2, __NANO_ESF_a2_OFFSET(sp)
	lw a3, __NANO_ESF_a3_OFFSET(sp)
	lw a4, __NANO_ESF_a4_OFFSET(sp)
	lw a5, __NANO_ESF_a5_OFFSET(sp)
	lw a6, __NANO_ESF_a6_OFFSET(sp)
	lw a7, __NANO_ESF_a7_OFFSET(sp)

	/* Release stack space */
	addi sp, sp, __NANO_ESF_SIZEOF
#endif
	ecall

	/*
	 * when thread is rescheduled, unlock irq and return.
	 * Restored register a0 contains IRQ lock state of thread.
	 *
	 * Prior to unlocking irq, load return value of
	 * __swap to temp register t2 (from
	 * _thread_offset_to_swap_return_value). Normally, it should be -EAGAIN,
	 * unless someone has previously called z_set_thread_return_value(..).
	 */
	la t0, _kernel

	/* Get pointer to _kernel.current */
	lw t1, _kernel_offset_to_current(t0)

	/* Load return value of __swap function in temp register t2 */
	lw t2, _thread_offset_to_swap_return_value(t1)

	/*
	 * Unlock irq, following IRQ lock state in a0 register.
	 * Use atomic instruction csrrs to do so.
	 */
	andi a0, a0, SOC_MSTATUS_IEN
	csrrs t0, mstatus, a0

	/* Set value of return register a0 to value of register t2 */
	addi a0, t2, 0

	/* Return */
	jalr x0, ra

#else

/* void z_arch_switch(void *switch_to, void **switched_from)*/

SECTION_FUNC(exception.other, z_arch_switch)

	/* Make a system call to perform context switch */
#ifdef CONFIG_EXECUTION_BENCHMARKING
	addi sp, sp, -__NANO_ESF_SIZEOF

	sw ra, __NANO_ESF_ra_OFFSET(sp)
	sw gp, __NANO_ESF_gp_OFFSET(sp)
	sw tp, __NANO_ESF_tp_OFFSET(sp)
	sw t0, __NANO_ESF_t0_OFFSET(sp)
	sw t1, __NANO_ESF_t1_OFFSET(sp)
	sw t2, __NANO_ESF_t2_OFFSET(sp)
	sw t3, __NANO_ESF_t3_OFFSET(sp)
	sw t4, __NANO_ESF_t4_OFFSET(sp)
	sw t5, __NANO_ESF_t5_OFFSET(sp)
	sw t6, __NANO_ESF_t6_OFFSET(sp)
	sw a0, __NANO_ESF_a0_OFFSET(sp)
	sw a1, __NANO_ESF_a1_OFFSET(sp)
	sw a2, __NANO_ESF_a2_OFFSET(sp)
	sw a3, __NANO_ESF_a3_OFFSET(sp)
	sw a4, __NANO_ESF_a4_OFFSET(sp)
	sw a5, __NANO_ESF_a5_OFFSET(sp)
	sw a6, __NANO_ESF_a6_OFFSET(sp)
	sw a7, __NANO_ESF_a7_OFFSET(sp)

	call read_timer_start_of_swap

	lw ra, __NANO_ESF_ra_OFFSET(sp)
	lw gp, __NANO_ESF_gp_OFFSET(sp)
	lw tp, __NANO_ESF_tp_OFFSET(sp)
	lw t0, __NANO_ESF_t0_OFFSET(sp)
	lw t1, __NANO_ESF_t1_OFFSET(sp)
	lw t2, __NANO_ESF_t2_OFFSET(sp)
	lw t3, __NANO_ESF_t3_OFFSET(sp)
	lw t4, __NANO_ESF_t4_OFFSET(sp)
	lw t5, __NANO_ESF_t5_OFFSET(sp)
	lw t6, __NANO_ESF_t6_OFFSET(sp)
	lw a0, __NANO_ESF_a0_OFFSET(sp)
	lw a1, __NANO_ESF_a1_OFFSET(sp)
	lw a2, __NANO_ESF_a2_OFFSET(sp)
	lw a3, __NANO_ESF_a3_OFFSET(sp)
	lw a4, __NANO_ESF_a4_OFFSET(sp)
	lw a5, __NANO_ESF_a5_OFFSET(sp)
	lw a6, __NANO_ESF_a6_OFFSET(sp)
	lw a7, __NANO_ESF_a7_OFFSET(sp)

	/* Release stack space */
	addi sp, sp, __NANO_ESF_SIZEOF
#endif

	lw a1, 0(a1)
	beqz a1, no_need_save
	sw sp, __SWITCH_HDL_sp_OFFSET(a1)
	sw s0, __SWITCH_HDL_s0_OFFSET(a1)
	sw s1, __SWITCH_HDL_s1_OFFSET(a1)
	sw s2, __SWITCH_HDL_s2_OFFSET(a1)
	sw s3, __SWITCH_HDL_s3_OFFSET(a1)
	sw s4, __SWITCH_HDL_s4_OFFSET(a1)
	sw s5, __SWITCH_HDL_s5_OFFSET(a1)
	sw s6, __SWITCH_HDL_s6_OFFSET(a1)
	sw s7, __SWITCH_HDL_s7_OFFSET(a1)
	sw s8, __SWITCH_HDL_s8_OFFSET(a1)
	sw s9, __SWITCH_HDL_s9_OFFSET(a1)
	sw s10, __SWITCH_HDL_s10_OFFSET(a1)
	sw s11, __SWITCH_HDL_s11_OFFSET(a1)
	addi a1, a1, __SWITCH_HDL_max_OFFSET
	csrrci t0, mstatus, SOC_MSTATUS_IEN
	csrr t1, mstatus
	andi t0, t0, SOC_MSTATUS_IEN
	beqz t0, 1f
	ori  t1, t1, SOC_MSTATUS_MPIE
1:
	li t2, SOC_MSTATUS_MPP_M_MODE
	or t1, t1, t2
	sw t1, __NANO_ESF_mstatus_OFFSET(a1)
	sw ra, __NANO_ESF_mepc_OFFSET(a1)

no_need_save:

	/* restore new switch handle */

	lw s0, __SWITCH_HDL_s0_OFFSET(a0)
	lw s1, __SWITCH_HDL_s1_OFFSET(a0)
	lw s2, __SWITCH_HDL_s2_OFFSET(a0)
	lw s3, __SWITCH_HDL_s3_OFFSET(a0)
	lw s4, __SWITCH_HDL_s4_OFFSET(a0)
	lw s5, __SWITCH_HDL_s5_OFFSET(a0)
	lw s6, __SWITCH_HDL_s6_OFFSET(a0)
	lw s7, __SWITCH_HDL_s7_OFFSET(a0)
	lw s8, __SWITCH_HDL_s8_OFFSET(a0)
	lw s9, __SWITCH_HDL_s9_OFFSET(a0)
	lw s10, __SWITCH_HDL_s10_OFFSET(a0)
	lw s11, __SWITCH_HDL_s11_OFFSET(a0)
	lw sp, __SWITCH_HDL_sp_OFFSET(a0)
	addi a0, a0, __SWITCH_HDL_max_OFFSET
	lw t0, __NANO_ESF_mepc_OFFSET(a0)
	csrw mepc, t0
	lw t0, __NANO_ESF_mstatus_OFFSET(a0)
	csrw mstatus, t0
	lw ra, __NANO_ESF_ra_OFFSET(a0)
	lw gp, __NANO_ESF_gp_OFFSET(a0)
	lw tp, __NANO_ESF_tp_OFFSET(a0)
	lw t0, __NANO_ESF_t0_OFFSET(a0)
	lw t1, __NANO_ESF_t1_OFFSET(a0)
	lw t2, __NANO_ESF_t2_OFFSET(a0)
	lw t3, __NANO_ESF_t3_OFFSET(a0)
	lw t4, __NANO_ESF_t4_OFFSET(a0)
	lw t5, __NANO_ESF_t5_OFFSET(a0)
	lw t6, __NANO_ESF_t6_OFFSET(a0)
	lw a1, __NANO_ESF_a1_OFFSET(a0)
	lw a2, __NANO_ESF_a2_OFFSET(a0)
	lw a3, __NANO_ESF_a3_OFFSET(a0)
	lw a4, __NANO_ESF_a4_OFFSET(a0)
	lw a5, __NANO_ESF_a5_OFFSET(a0)
	lw a6, __NANO_ESF_a6_OFFSET(a0)
	lw a7, __NANO_ESF_a7_OFFSET(a0)
	lw a0, __NANO_ESF_a0_OFFSET(a0)

#ifdef CONFIG_EXECUTION_BENCHMARKING
	addi sp, sp, -__NANO_ESF_SIZEOF

	sw ra, __NANO_ESF_ra_OFFSET(sp)
	sw gp, __NANO_ESF_gp_OFFSET(sp)
	sw tp, __NANO_ESF_tp_OFFSET(sp)
	sw t0, __NANO_ESF_t0_OFFSET(sp)
	sw t1, __NANO_ESF_t1_OFFSET(sp)
	sw t2, __NANO_ESF_t2_OFFSET(sp)
	sw t3, __NANO_ESF_t3_OFFSET(sp)
	sw t4, __NANO_ESF_t4_OFFSET(sp)
	sw t5, __NANO_ESF_t5_OFFSET(sp)
	sw t6, __NANO_ESF_t6_OFFSET(sp)
	sw a0, __NANO_ESF_a0_OFFSET(sp)
	sw a1, __NANO_ESF_a1_OFFSET(sp)
	sw a2, __NANO_ESF_a2_OFFSET(sp)
	sw a3, __NANO_ESF_a3_OFFSET(sp)
	sw a4, __NANO_ESF_a4_OFFSET(sp)
	sw a5, __NANO_ESF_a5_OFFSET(sp)
	sw a6, __NANO_ESF_a6_OFFSET(sp)
	sw a7, __NANO_ESF_a7_OFFSET(sp)

	call read_timer_end_of_swap

	lw ra, __NANO_ESF_ra_OFFSET(sp)
	lw gp, __NANO_ESF_gp_OFFSET(sp)
	lw tp, __NANO_ESF_tp_OFFSET(sp)
	lw t0, __NANO_ESF_t0_OFFSET(sp)
	lw t1, __NANO_ESF_t1_OFFSET(sp)
	lw t2, __NANO_ESF_t2_OFFSET(sp)
	lw t3, __NANO_ESF_t3_OFFSET(sp)
	lw t4, __NANO_ESF_t4_OFFSET(sp)
	lw t5, __NANO_ESF_t5_OFFSET(sp)
	lw t6, __NANO_ESF_t6_OFFSET(sp)
	lw a0, __NANO_ESF_a0_OFFSET(sp)
	lw a1, __NANO_ESF_a1_OFFSET(sp)
	lw a2, __NANO_ESF_a2_OFFSET(sp)
	lw a3, __NANO_ESF_a3_OFFSET(sp)
	lw a4, __NANO_ESF_a4_OFFSET(sp)
	lw a5, __NANO_ESF_a5_OFFSET(sp)
	lw a6, __NANO_ESF_a6_OFFSET(sp)
	lw a7, __NANO_ESF_a7_OFFSET(sp)

	/* Release stack space */
	addi sp, sp, __NANO_ESF_SIZEOF
#endif

	mret

#endif

/*
 * void z_thread_entry_wrapper(k_thread_entry_t, void *, void *, void *)
 */
SECTION_FUNC(TEXT, z_thread_entry_wrapper)
	/*
	 * z_thread_entry_wrapper is called for every new thread upon the return
	 * of __swap or ISR. Its address, as well as its input function
	 * arguments thread_entry_t, void *, void *, void * are restored from
	 * the thread stack (initialized via function _thread).
	 * In this case, thread_entry_t, * void *, void * and void * are stored
	 * in registers a0, a1, a2 and a3. These registers are used as arguments
	 * to function z_thread_entry. Hence, just call z_thread_entry with
	 * return address set to 0 to indicate a non-returning function call.
	 */

	jal x0, z_thread_entry
