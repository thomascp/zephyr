# SPDX-License-Identifier: Apache-2.0

set(EMU_PLATFORM qemu)

set(QEMU_CPU_TYPE_${ARCH} riscv64)

set(QEMU_FLAGS_${ARCH}
  -nographic
  -machine sifive_u
  )

set(BOARD_DEBUG_RUNNER qemu)
set(BOARD_FLASH_RUNNER hifive_unleashed)
board_finalize_runner_args(hifive_unleashed)