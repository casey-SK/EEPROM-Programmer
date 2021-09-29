cmake_minimum_required(VERSION 3.13)

# initialize the SDK based on PICO_SDK_PATH

# note: this must happen before project()
include(pico_sdk_import.cmake)

project(eeprom_programmer)

# initialize the Raspberry Pi Pico SDK
pico_sdk_init()

# add program file(s)
file(GLOB MyCSources *.c)
add_executable(eeprom_programmer ${MyCSources})

# pull in our pico_stdlib which pulls in commonly used features
# hardware_adc tinyusb_device tinyusb_board Currently supported.
target_link_libraries(eeprom_programmer pico_stdlib hardware_adc)

# enable usb output, disable uart output
pico_enable_stdio_usb(eeprom_programmer 1)
pico_enable_stdio_uart(eeprom_programmer 0)

# create map/bin/hex/uf2 file etc.
pico_add_extra_outputs(eeprom_programmer)

# add url via pico_set_program_url
pico_set_program_url(eeprom_programmer 1)
