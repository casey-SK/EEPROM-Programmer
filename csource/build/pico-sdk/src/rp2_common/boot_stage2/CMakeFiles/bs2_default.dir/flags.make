# CMAKE generated file: DO NOT EDIT!
# Generated by "Unix Makefiles" Generator, CMake Version 3.18

# compile ASM with /usr/bin/arm-none-eabi-gcc
ASM_DEFINES = -DPICO_BOARD=\"pico\" -DPICO_BUILD=1 -DPICO_NO_HARDWARE=0 -DPICO_ON_DEVICE=1

ASM_INCLUDES = -I/home/casey/pico-sdk/src/rp2_common/boot_stage2/asminclude -I/home/casey/pico-sdk/src/rp2040/hardware_regs/include -I/home/casey/pico-sdk/src/rp2_common/hardware_base/include -I/home/casey/pico-sdk/src/common/pico_base/include -I"/home/casey/Documents/Learning/nim/pico-nim eeprom programmer/eeprom_programmer/csource/build/generated/pico_base" -I/home/casey/pico-sdk/src/boards/include -I/home/casey/pico-sdk/src/rp2_common/pico_platform/include -I/home/casey/pico-sdk/src/rp2_common/boot_stage2/include

ASM_FLAGS = -mcpu=cortex-m0plus -mthumb -O3 -DNDEBUG
