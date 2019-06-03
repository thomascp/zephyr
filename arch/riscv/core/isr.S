/*
 * Copyright (c) 2016 Jean-Paul Etienne <fractalclone@gmail.com>
 * Copyright (c) 2018 Foundries.io Ltd
 *
 * SPDX-License-Identifier: Apache-2.0
 */

#include <toolchain.h>
#include <linker/sections.h>
#include <kernel_structs.h>
#include <offsets_short.h>
#include <kernel_arch_thread.h>
#include <arch/cpu.h>

/* imports */
GDATA(_sw_isr_table)
GTEXT(__soc_is_irq)
GTEXT(__soc_handle_irq)
GTEXT(_Fault)
#ifdef CONFIG_RISCV_SOC_CONTEXT_SAVE
GTEXT(__soc_save_context)
GTEXT(__soc_restore_context)
#endif /* CONFIG_RISCV_SOC_CONTEXT_SAVE */

GTEXT(_k_neg_eagain)
GTEXT(_is_next_thread_current)
GTEXT(z_get_next_ready_thread)

#ifdef CONFIG_TRACING
GTEXT(z_sys_trace_thread_switched_in)
GTEXT(z_sys_trace_isr_enter)
#endif

#ifdef CONFIG_IRQ_OFFLOAD
GTEXT(_offload_routine)
GTEXT(z_irq_get_offload)
#endif

/* exports */
GTEXT(__irq_wrapper)

/* use ABI name of registers for the sake of simplicity */

/*
 * Generic architecture-level IRQ handling, along with callouts to
 * SoC-specific routines.
 *
 * Architecture level IRQ handling includes basic context save/restore
 * of standard registers and calling ISRs registered at Zephyr's driver
 * level.
 *
 * Since RISC-V does not completely prescribe IRQ handling behavior,
 * implementations vary (some implementations also deviate from
 * what standard behavior is defined). Hence, the arch level code expects
 * the following functions to be provided at the SOC level:
 *
 *     - __soc_is_irq: decide if we're handling an interrupt or an exception
 *     - __soc_handle_irq: handle SoC-specific details for a pending IRQ
 *       (e.g. clear a pending bit in a SoC-specific register)
 *
 * If CONFIG_RISCV_SOC_CONTEXT_SAVE=y, calls to SoC-level context save/restore
 * routines are also made here. For details, see the Kconfig help text.
 */

/*
 * Handler called upon each exception/interrupt/fault
 * In this architecture, system call (ECALL) is used to perform context
 * switching or IRQ offloading (when enabled).
 */
SECTION_FUNC(exception.entry, __irq_wrapper)
	/* Allocate space on thread stack to save registers */
	addi sp, sp, -__NANO_ESF_SIZEOF

	/*
	 * Save caller-saved registers on current thread stack.
	 * NOTE: need to be updated to account for floating-point registers
	 * floating-point registers should be accounted for when corresponding
	 * config variable is set
	 */
	SR ra, __NANO_ESF_ra_OFFSET(sp)
	SR gp, __NANO_ESF_gp_OFFSET(sp)
	SR tp, __NANO_ESF_tp_OFFSET(sp)
	SR t0, __NANO_ESF_t0_OFFSET(sp)
	SR t1, __NANO_ESF_t1_OFFSET(sp)
	SR t2, __NANO_ESF_t2_OFFSET(sp)
	SR t3, __NANO_ESF_t3_OFFSET(sp)
	SR t4, __NANO_ESF_t4_OFFSET(sp)
	SR t5, __NANO_ESF_t5_OFFSET(sp)
	SR t6, __NANO_ESF_t6_OFFSET(sp)
	SR a0, __NANO_ESF_a0_OFFSET(sp)
	SR a1, __NANO_ESF_a1_OFFSET(sp)
	SR a2, __NANO_ESF_a2_OFFSET(sp)
	SR a3, __NANO_ESF_a3_OFFSET(sp)
	SR a4, __NANO_ESF_a4_OFFSET(sp)
	SR a5, __NANO_ESF_a5_OFFSET(sp)
	SR a6, __NANO_ESF_a6_OFFSET(sp)
	SR a7, __NANO_ESF_a7_OFFSET(sp)

	/* Save MEPC register */
	csrr t0, mepc
	SR t0, __NANO_ESF_mepc_OFFSET(sp)

	/* Save SOC-specific MSTATUS register */
	csrr t0, SOC_MSTATUS_REG
	SR t0, __NANO_ESF_mstatus_OFFSET(sp)

#ifdef CONFIG_RISCV_SOC_CONTEXT_SAVE
	/* Handle context saving at SOC level. */
	addi a0, sp, __NANO_ESF_soc_context_OFFSET
	jal ra, __soc_save_context
#endif /* CONFIG_RISCV_SOC_CONTEXT_SAVE */

#ifdef CONFIG_EXECUTION_BENCHMARKING
	call read_timer_start_of_isr
#endif

	/*
	 * Check if exception is the result of an interrupt or not.
	 * (SOC dependent). Following the RISC-V architecture spec, the MSB
	 * of the mcause register is used to indicate whether an exception
	 * is the result of an interrupt or an exception/fault. But for some
	 * SOCs (like pulpino or riscv-qemu), the MSB is never set to indicate
	 * interrupt. Hence, check for interrupt/exception via the __soc_is_irq
	 * function (that needs to be implemented by each SOC). The result is
	 * returned via register a0 (1: interrupt, 0 exception)
	 */
	jal ra, __soc_is_irq

	/* If a0 != 0, jump to is_interrupt */
	addi t1, x0, 0
	bnez a0, is_interrupt

	/*
	 * If the exception is the result of an ECALL, check whether to
	 * perform a context-switch or an IRQ offload. Otherwise call _Fault
	 * to report the exception.
	 */
	csrr t0, mcause
	li t2, SOC_MCAUSE_EXP_MASK
	and t0, t0, t2
	li t1, SOC_MCAUSE_ECALL_EXP

	/*
	 * If mcause == SOC_MCAUSE_ECALL_EXP, handle system call,
	 * otherwise handle fault
	 */
	beq t0, t1, is_syscall

	/*
	 * Call _Fault to handle exception.
	 * Stack pointer is pointing to a NANO_ESF structure, pass it
	 * to _Fault (via register a0).
	 * If _Fault shall return, set return address to no_reschedule
	 * to restore stack.
	 */
	addi a0, sp, 0
	la ra, no_reschedule
	tail _Fault

is_syscall:
	/*
	 * A syscall is the result of an ecall instruction, in which case the
	 * MEPC will contain the address of the ecall instruction.
	 * Increment saved MEPC by 4 to prevent triggering the same ecall
	 * again upon exiting the ISR.
	 *
	 * It is safe to always increment by 4, even with compressed
	 * instructions, because the ecall instruction is always 4 bytes.
	 */
	LR t0, __NANO_ESF_mepc_OFFSET(sp)
	addi t0, t0, 4
	SR t0, __NANO_ESF_mepc_OFFSET(sp)

#ifdef CONFIG_IRQ_OFFLOAD
	/*
	 * Determine if the system call is the result of an IRQ offloading.
	 * Done by checking if _offload_routine is not pointing to NULL.
	 * If NULL, jump to reschedule to perform a context-switch, otherwise,
	 * jump to is_interrupt to handle the IRQ offload.
	 */
	call z_irq_get_offload
	mv t1, a0
	bnez t1, is_interrupt
#endif

#ifndef CONFIG_SMP
	/*
	 * Go to reschedule to handle context-switch
	 */
	j reschedule

#else
	/* in smp mode, this is impossible */

dead:
	j dead

#endif

is_interrupt:
	/*
	 * Save current thread stack pointer and switch
	 * stack pointer to interrupt stack.
	 */

#ifndef CONFIG_SMP

	/* Save thread stack pointer to temp register t0 */
	addi t0, sp, 0

	/* Switch to interrupt stack */
	la t2, _kernel
	LR sp, _kernel_offset_to_irq_stack(t2)

#else

	/* t1 is saved as _offload_routine */
	addi sp, sp, -STACK_ALIGN
	SR t1, 0(sp)
	call riscv_get_curr_cpu
	LR t1, 0(sp)
	addi sp, sp, STACK_ALIGN

	/* Save thread stack pointer to temp register t0 */
	mv t0, sp

	/* Switch to interrupt stack */
	mv t2, a0
	LR sp, ___cpu_t_irq_stack_OFFSET(t2)

#endif

	/*
	 * Save thread stack pointer on interrupt stack
	 * In RISC-V, stack pointer needs to be 16-byte aligned
	 */
	addi sp, sp, -STACK_ALIGN
	SR t0, 0x00(sp)

on_irq_stack:
	/* Increment _kernel.nested variable */
	lw t3, ___cpu_t_nested_OFFSET(t2)
	addi t3, t3, 1
	sw t3, ___cpu_t_nested_OFFSET(t2)

	/*
	 * If we are here due to a system call, t1 register should != 0.
	 * In this case, perform IRQ offloading, otherwise jump to call_irq
	 */
	beqz t1, call_irq

	/*
	 * Call z_irq_do_offload to handle IRQ offloading.
	 * Set return address to on_thread_stack in order to jump there
	 * upon returning from z_irq_do_offload
	 */
	la ra, on_thread_stack
	tail z_irq_do_offload

call_irq:
#ifdef CONFIG_TRACING
	call z_sys_trace_isr_enter
#endif

	/* Get IRQ causing interrupt */
	csrr a0, mcause
	li t0, SOC_MCAUSE_EXP_MASK
	and a0, a0, t0

	/*
	 * Clear pending IRQ generating the interrupt at SOC level
	 * Pass IRQ number to __soc_handle_irq via register a0
	 */
	jal ra, __soc_handle_irq

	/*
	 * Call corresponding registered function in _sw_isr_table.
	 * (table is 8-bytes wide, we should shift index by 3)
	 */
	la t0, _sw_isr_table
	slli a0, a0, ISR_TABLE_SHIFT
	add t0, t0, a0

	/* Load argument in a0 register */
	LR a0, 0x00(t0)

	/* Load ISR function address in register t1 */
	LR t1, RISCV_REG_SIZE(t0)

#ifdef CONFIG_EXECUTION_BENCHMARKING
	addi sp, sp, -STACK_ALIGN
	SR a0, 0x00(sp)
	SR t1, RISCV_REG_SIZE(sp)
	call read_timer_end_of_isr
	LR t1, RISCV_REG_SIZE(sp)
	LR a0, 0x00(sp)
	addi sp, sp, STACK_ALIGN
#endif
	/* Call ISR function */
	jalr ra, t1

on_thread_stack:

#ifndef CONFIG_SMP

	/* Get reference to _kernel */
	la t1, _kernel

#else

	call riscv_get_curr_cpu
	mv t1, a0

#endif

	/* Decrement _kernel.nested variable */
	lw t2, ___cpu_t_nested_OFFSET(t1)
	addi t2, t2, -1
	sw t2, ___cpu_t_nested_OFFSET(t1)

	/* Restore thread stack pointer */
	LR t0, 0x00(sp)
	addi sp, t0, 0

#ifdef CONFIG_STACK_SENTINEL
	call z_check_stack_sentinel

#ifndef CONFIG_SMP

	/* Get reference to _kernel */
	la t1, _kernel

#else

	call riscv_get_curr_cpu
	mv t1, a0

#endif

#endif

#ifdef CONFIG_PREEMPT_ENABLED

#ifndef CONFIG_SMP

	/*
	 * Check if we need to perform a reschedule
	 */

	/* Get pointer to _kernel.current */
	LR t2, _kernel_offset_to_current(t1)

	/*
	 * Check if next thread to schedule is current thread.
	 * If yes do not perform a reschedule
	 */
	LR t3, _kernel_offset_to_ready_q_cache(t1)
	beq t3, t2, no_reschedule

#else /* CONFIG_SMP */

	addi a1, sp, -__SWITCH_HDL_max_OFFSET
	mv a0, a1
	call z_get_next_switch_handle
	beq a1, a0, no_reschedule
	j reschedule

#endif

#else
	j no_reschedule
#endif /* CONFIG_PREEMPT_ENABLED */

reschedule:

#ifndef CONFIG_SMP

#if CONFIG_TRACING
	call z_sys_trace_thread_switched_in
#endif
	/* Get reference to _kernel */
	la t0, _kernel

	/* Get pointer to _kernel.current */
	LR t1, _kernel_offset_to_current(t0)

	/*
	 * Save callee-saved registers of current thread
	 * prior to handle context-switching
	 */
	SR s0, _thread_offset_to_s0(t1)
	SR s1, _thread_offset_to_s1(t1)
	SR s2, _thread_offset_to_s2(t1)
	SR s3, _thread_offset_to_s3(t1)
	SR s4, _thread_offset_to_s4(t1)
	SR s5, _thread_offset_to_s5(t1)
	SR s6, _thread_offset_to_s6(t1)
	SR s7, _thread_offset_to_s7(t1)
	SR s8, _thread_offset_to_s8(t1)
	SR s9, _thread_offset_to_s9(t1)
	SR s10, _thread_offset_to_s10(t1)
	SR s11, _thread_offset_to_s11(t1)

	/*
	 * Save stack pointer of current thread and set the default return value
	 * of z_swap to _k_neg_eagain for the thread.
	 */
	SR sp, _thread_offset_to_sp(t1)
	la t2, _k_neg_eagain
	lw t3, 0x00(t2)
	sw t3, _thread_offset_to_swap_return_value(t1)

	/* Get next thread to schedule. */
	LR t1, _kernel_offset_to_ready_q_cache(t0)

	/*
	 * Set _kernel.current to new thread loaded in t1
	 */
	SR t1, _kernel_offset_to_current(t0)

	/* Switch to new thread stack */
	LR sp, _thread_offset_to_sp(t1)

	/* Restore callee-saved registers of new thread */
	LR s0, _thread_offset_to_s0(t1)
	LR s1, _thread_offset_to_s1(t1)
	LR s2, _thread_offset_to_s2(t1)
	LR s3, _thread_offset_to_s3(t1)
	LR s4, _thread_offset_to_s4(t1)
	LR s5, _thread_offset_to_s5(t1)
	LR s6, _thread_offset_to_s6(t1)
	LR s7, _thread_offset_to_s7(t1)
	LR s8, _thread_offset_to_s8(t1)
	LR s9, _thread_offset_to_s9(t1)
	LR s10, _thread_offset_to_s10(t1)
	LR s11, _thread_offset_to_s11(t1)

#ifdef CONFIG_EXECUTION_BENCHMARKING
	addi sp, sp, -__NANO_ESF_SIZEOF

	SR ra, __NANO_ESF_ra_OFFSET(sp)
	SR gp, __NANO_ESF_gp_OFFSET(sp)
	SR tp, __NANO_ESF_tp_OFFSET(sp)
	SR t0, __NANO_ESF_t0_OFFSET(sp)
	SR t1, __NANO_ESF_t1_OFFSET(sp)
	SR t2, __NANO_ESF_t2_OFFSET(sp)
	SR t3, __NANO_ESF_t3_OFFSET(sp)
	SR t4, __NANO_ESF_t4_OFFSET(sp)
	SR t5, __NANO_ESF_t5_OFFSET(sp)
	SR t6, __NANO_ESF_t6_OFFSET(sp)
	SR a0, __NANO_ESF_a0_OFFSET(sp)
	SR a1, __NANO_ESF_a1_OFFSET(sp)
	SR a2, __NANO_ESF_a2_OFFSET(sp)
	SR a3, __NANO_ESF_a3_OFFSET(sp)
	SR a4, __NANO_ESF_a4_OFFSET(sp)
	SR a5, __NANO_ESF_a5_OFFSET(sp)
	SR a6, __NANO_ESF_a6_OFFSET(sp)
	SR a7, __NANO_ESF_a7_OFFSET(sp)

	call read_timer_end_of_swap

	SR ra, __NANO_ESF_ra_OFFSET(sp)
	SR gp, __NANO_ESF_gp_OFFSET(sp)
	SR tp, __NANO_ESF_tp_OFFSET(sp)
	SR t0, __NANO_ESF_t0_OFFSET(sp)
	SR t1, __NANO_ESF_t1_OFFSET(sp)
	SR t2, __NANO_ESF_t2_OFFSET(sp)
	SR t3, __NANO_ESF_t3_OFFSET(sp)
	SR t4, __NANO_ESF_t4_OFFSET(sp)
	SR t5, __NANO_ESF_t5_OFFSET(sp)
	SR t6, __NANO_ESF_t6_OFFSET(sp)
	SR a0, __NANO_ESF_a0_OFFSET(sp)
	SR a1, __NANO_ESF_a1_OFFSET(sp)
	SR a2, __NANO_ESF_a2_OFFSET(sp)
	SR a3, __NANO_ESF_a3_OFFSET(sp)
	SR a4, __NANO_ESF_a4_OFFSET(sp)
	SR a5, __NANO_ESF_a5_OFFSET(sp)
	SR a6, __NANO_ESF_a6_OFFSET(sp)
	SR a7, __NANO_ESF_a7_OFFSET(sp)

	/* Release stack space */
	addi sp, sp, __NANO_ESF_SIZEOF
#endif

#else   /* SMP */

#if CONFIG_TRACING
	addi sp, sp, -STACK_ALIGN
	SR a0, 0(sp)
	SR a1, RISCV_REG_SIZE(sp)
	call z_sys_trace_thread_switched_in
	LR a0, 0(sp)
	LR a1, RISCV_REG_SIZE(sp)
	addi sp, sp, STACK_ALIGN
#endif

#ifdef CONFIG_EXECUTION_BENCHMARKING
	addi sp, sp, -__NANO_ESF_SIZEOF

	SR ra, __NANO_ESF_ra_OFFSET(sp)
	SR gp, __NANO_ESF_gp_OFFSET(sp)
	SR tp, __NANO_ESF_tp_OFFSET(sp)
	SR t0, __NANO_ESF_t0_OFFSET(sp)
	SR t1, __NANO_ESF_t1_OFFSET(sp)
	SR t2, __NANO_ESF_t2_OFFSET(sp)
	SR t3, __NANO_ESF_t3_OFFSET(sp)
	SR t4, __NANO_ESF_t4_OFFSET(sp)
	SR t5, __NANO_ESF_t5_OFFSET(sp)
	SR t6, __NANO_ESF_t6_OFFSET(sp)
	SR a0, __NANO_ESF_a0_OFFSET(sp)
	SR a1, __NANO_ESF_a1_OFFSET(sp)
	SR a2, __NANO_ESF_a2_OFFSET(sp)
	SR a3, __NANO_ESF_a3_OFFSET(sp)
	SR a4, __NANO_ESF_a4_OFFSET(sp)
	SR a5, __NANO_ESF_a5_OFFSET(sp)
	SR a6, __NANO_ESF_a6_OFFSET(sp)
	SR a7, __NANO_ESF_a7_OFFSET(sp)

	call read_timer_start_of_swap

	LR ra, __NANO_ESF_ra_OFFSET(sp)
	LR gp, __NANO_ESF_gp_OFFSET(sp)
	LR tp, __NANO_ESF_tp_OFFSET(sp)
	LR t0, __NANO_ESF_t0_OFFSET(sp)
	LR t1, __NANO_ESF_t1_OFFSET(sp)
	LR t2, __NANO_ESF_t2_OFFSET(sp)
	LR t3, __NANO_ESF_t3_OFFSET(sp)
	LR t4, __NANO_ESF_t4_OFFSET(sp)
	LR t5, __NANO_ESF_t5_OFFSET(sp)
	LR t6, __NANO_ESF_t6_OFFSET(sp)
	LR a0, __NANO_ESF_a0_OFFSET(sp)
	LR a1, __NANO_ESF_a1_OFFSET(sp)
	LR a2, __NANO_ESF_a2_OFFSET(sp)
	LR a3, __NANO_ESF_a3_OFFSET(sp)
	LR a4, __NANO_ESF_a4_OFFSET(sp)
	LR a5, __NANO_ESF_a5_OFFSET(sp)
	LR a6, __NANO_ESF_a6_OFFSET(sp)
	LR a7, __NANO_ESF_a7_OFFSET(sp)

	/* Release stack space */
	addi sp, sp, __NANO_ESF_SIZEOF
#endif

	/* a0 is new switch handle, a1 is the old one */
	addi t0, sp, __NANO_ESF_SIZEOF
	addi sp, sp, -__SWITCH_HDL_max_OFFSET
	SR t0, __SWITCH_HDL_sp_OFFSET(sp)
	SR s0, __SWITCH_HDL_s0_OFFSET(sp)
	SR s1, __SWITCH_HDL_s1_OFFSET(sp)
	SR s2, __SWITCH_HDL_s2_OFFSET(sp)
	SR s3, __SWITCH_HDL_s3_OFFSET(sp)
	SR s4, __SWITCH_HDL_s4_OFFSET(sp)
	SR s5, __SWITCH_HDL_s5_OFFSET(sp)
	SR s6, __SWITCH_HDL_s6_OFFSET(sp)
	SR s7, __SWITCH_HDL_s7_OFFSET(sp)
	SR s8, __SWITCH_HDL_s8_OFFSET(sp)
	SR s9, __SWITCH_HDL_s9_OFFSET(sp)
	SR s10, __SWITCH_HDL_s10_OFFSET(sp)
	SR s11, __SWITCH_HDL_s11_OFFSET(sp)

	/* restore new switch handle */

	LR s0, __SWITCH_HDL_s0_OFFSET(a0)
	LR s1, __SWITCH_HDL_s1_OFFSET(a0)
	LR s2, __SWITCH_HDL_s2_OFFSET(a0)
	LR s3, __SWITCH_HDL_s3_OFFSET(a0)
	LR s4, __SWITCH_HDL_s4_OFFSET(a0)
	LR s5, __SWITCH_HDL_s5_OFFSET(a0)
	LR s6, __SWITCH_HDL_s6_OFFSET(a0)
	LR s7, __SWITCH_HDL_s7_OFFSET(a0)
	LR s8, __SWITCH_HDL_s8_OFFSET(a0)
	LR s9, __SWITCH_HDL_s9_OFFSET(a0)
	LR s10, __SWITCH_HDL_s10_OFFSET(a0)
	LR s11, __SWITCH_HDL_s11_OFFSET(a0)
	LR sp, __SWITCH_HDL_sp_OFFSET(a0)
	addi a0, a0, __SWITCH_HDL_max_OFFSET
	LR t0, __NANO_ESF_mepc_OFFSET(a0)
	csrw mepc, t0
	LR t0, __NANO_ESF_mstatus_OFFSET(a0)
	csrw mstatus, t0
	LR ra, __NANO_ESF_ra_OFFSET(a0)
	LR gp, __NANO_ESF_gp_OFFSET(a0)
	LR tp, __NANO_ESF_tp_OFFSET(a0)
	LR t0, __NANO_ESF_t0_OFFSET(a0)
	LR t1, __NANO_ESF_t1_OFFSET(a0)
	LR t2, __NANO_ESF_t2_OFFSET(a0)
	LR t3, __NANO_ESF_t3_OFFSET(a0)
	LR t4, __NANO_ESF_t4_OFFSET(a0)
	LR t5, __NANO_ESF_t5_OFFSET(a0)
	LR t6, __NANO_ESF_t6_OFFSET(a0)
	LR a1, __NANO_ESF_a1_OFFSET(a0)
	LR a2, __NANO_ESF_a2_OFFSET(a0)
	LR a3, __NANO_ESF_a3_OFFSET(a0)
	LR a4, __NANO_ESF_a4_OFFSET(a0)
	LR a5, __NANO_ESF_a5_OFFSET(a0)
	LR a6, __NANO_ESF_a6_OFFSET(a0)
	LR a7, __NANO_ESF_a7_OFFSET(a0)
	LR a0, __NANO_ESF_a0_OFFSET(a0)

#ifdef CONFIG_EXECUTION_BENCHMARKING
	addi sp, sp, -__NANO_ESF_SIZEOF

	SR ra, __NANO_ESF_ra_OFFSET(sp)
	SR gp, __NANO_ESF_gp_OFFSET(sp)
	SR tp, __NANO_ESF_tp_OFFSET(sp)
	SR t0, __NANO_ESF_t0_OFFSET(sp)
	SR t1, __NANO_ESF_t1_OFFSET(sp)
	SR t2, __NANO_ESF_t2_OFFSET(sp)
	SR t3, __NANO_ESF_t3_OFFSET(sp)
	SR t4, __NANO_ESF_t4_OFFSET(sp)
	SR t5, __NANO_ESF_t5_OFFSET(sp)
	SR t6, __NANO_ESF_t6_OFFSET(sp)
	SR a0, __NANO_ESF_a0_OFFSET(sp)
	SR a1, __NANO_ESF_a1_OFFSET(sp)
	SR a2, __NANO_ESF_a2_OFFSET(sp)
	SR a3, __NANO_ESF_a3_OFFSET(sp)
	SR a4, __NANO_ESF_a4_OFFSET(sp)
	SR a5, __NANO_ESF_a5_OFFSET(sp)
	SR a6, __NANO_ESF_a6_OFFSET(sp)
	SR a7, __NANO_ESF_a7_OFFSET(sp)

	call read_timer_end_of_swap

	LR ra, __NANO_ESF_ra_OFFSET(sp)
	LR gp, __NANO_ESF_gp_OFFSET(sp)
	LR tp, __NANO_ESF_tp_OFFSET(sp)
	LR t0, __NANO_ESF_t0_OFFSET(sp)
	LR t1, __NANO_ESF_t1_OFFSET(sp)
	LR t2, __NANO_ESF_t2_OFFSET(sp)
	LR t3, __NANO_ESF_t3_OFFSET(sp)
	LR t4, __NANO_ESF_t4_OFFSET(sp)
	LR t5, __NANO_ESF_t5_OFFSET(sp)
	LR t6, __NANO_ESF_t6_OFFSET(sp)
	LR a0, __NANO_ESF_a0_OFFSET(sp)
	LR a1, __NANO_ESF_a1_OFFSET(sp)
	LR a2, __NANO_ESF_a2_OFFSET(sp)
	LR a3, __NANO_ESF_a3_OFFSET(sp)
	LR a4, __NANO_ESF_a4_OFFSET(sp)
	LR a5, __NANO_ESF_a5_OFFSET(sp)
	LR a6, __NANO_ESF_a6_OFFSET(sp)
	LR a7, __NANO_ESF_a7_OFFSET(sp)

	/* Release stack space */
	addi sp, sp, __NANO_ESF_SIZEOF
#endif

	SOC_ERET

#endif

no_reschedule:

#ifdef CONFIG_RISCV_SOC_CONTEXT_SAVE
	/* Restore context at SOC level */
	addi a0, sp, __NANO_ESF_soc_context_OFFSET
	jal ra, __soc_restore_context
#endif /* CONFIG_RISCV_SOC_CONTEXT_SAVE */

	/* Restore MEPC register */
	LR t0, __NANO_ESF_mepc_OFFSET(sp)
	csrw mepc, t0

	/* Restore SOC-specific MSTATUS register */
	LR t0, __NANO_ESF_mstatus_OFFSET(sp)
	csrw SOC_MSTATUS_REG, t0

	/* Restore caller-saved registers from thread stack */
	LR ra, __NANO_ESF_ra_OFFSET(sp)
	LR gp, __NANO_ESF_gp_OFFSET(sp)
	LR tp, __NANO_ESF_tp_OFFSET(sp)
	LR t0, __NANO_ESF_t0_OFFSET(sp)
	LR t1, __NANO_ESF_t1_OFFSET(sp)
	LR t2, __NANO_ESF_t2_OFFSET(sp)
	LR t3, __NANO_ESF_t3_OFFSET(sp)
	LR t4, __NANO_ESF_t4_OFFSET(sp)
	LR t5, __NANO_ESF_t5_OFFSET(sp)
	LR t6, __NANO_ESF_t6_OFFSET(sp)
	LR a0, __NANO_ESF_a0_OFFSET(sp)
	LR a1, __NANO_ESF_a1_OFFSET(sp)
	LR a2, __NANO_ESF_a2_OFFSET(sp)
	LR a3, __NANO_ESF_a3_OFFSET(sp)
	LR a4, __NANO_ESF_a4_OFFSET(sp)
	LR a5, __NANO_ESF_a5_OFFSET(sp)
	LR a6, __NANO_ESF_a6_OFFSET(sp)
	LR a7, __NANO_ESF_a7_OFFSET(sp)

	/* Release stack space */
	addi sp, sp, __NANO_ESF_SIZEOF

	/* Call SOC_ERET to exit ISR */
	SOC_ERET
