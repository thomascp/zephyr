Hi,

This repo was added riscv32/riscv64 SMP support for zephyr.

The support is a quick one which based on v1.14-branch, so only support limited features.

It is only tested on renode simulator sifive-fe310 and hifive-unleashed model.

Renode dir is the configuration of renode tools, some are modified for this quick support.

This work is just for fun!

Some useful script:

export ZEPHYR_SDK_INSTALL_DIR= export ZEPHYR_TOOLCHAIN_VARIANT=cross-compile export CROSS_COMPILE=/opt/riscv/bin/riscv64-unknown-linux-gnu-

cd .. rm -rf build; mkdir build; cd build cmake -DBOARD=hifive_unleashed .. make

include @scripts/single-node/hifive_unleashed.resc

/opt/riscv/bin/riscv64-unknown-linux-gnu-gdb /home/neo/zephyr/zephyr/samples/hello_world/build/zephyr/zephyr.elf target remote 127.0.0.1:1234 display /i $pc

/opt/riscv/bin/riscv64-unknown-linux-gnu-objdump -D /home/neo/zephyr/zephyr/samples/hello_world/build/zephyr/zephyr.elf| less

BR,
Peng

<img src="zephyr_rv64_1.jpg" width="50%" height="50%">
<img src="zephyr_rv64_2.jpg" width="50%" height="50%">
