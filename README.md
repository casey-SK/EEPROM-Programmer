# EEPROM Programmer using Raspberry Pi Pico and the Nim Programming Language

A [Nim](https://nim-lang.org/) Library that simplifies reading and writing to a 
parallel EEPROM. Supports using either *all* dedicated pins, or a hybrid of 
dedicated pins *and* a shift register (such as the **74HC595**). All though it 
is advertised for the **Raspberry Pi Pico**, all other RP2040-based 
microcontrollers should work.

supports the parallel EEPROM family that contains the following similar traits:
- 8 IO Pins (IO0 .. IO7)
- output enable (OE), and write enable (WE) are **active low**
- some number of address lines (supports up to 16 address lines)

in general, this means that the following EEPROMS may be supported:
- **28C16**
- 28C___ (any within this range)
- 28C256
- 28C512

**DISCLAIMER: Use this program at your own risk. The authors accept no** 
**responsibility for damage or injury!**

Note: **bold** values indicate hardware that has been tested. All others are
*untested*!

## Usage

### Dedicated Pin Arrangement

here is an example using dedicated pins:

![Fritzing Model of Pin Only Arrangement](/examples/example1_pinsOnly_sketch_breadboard.png)

*example1 code here*


### Hybrid Pin Arrangement

here is an example using a mix of dedicated and hybrid pins:

**Note:** The current implementation of this library only supports *shift-out*, 
not *shift-in*, so the data (IO) pins **MUST** be dedicated.

![Fritzing Model of Hybrid Arrangement](/examples/example2_hybrid_sketch_breadboard.png)

*example2 here*

## Installation

nimble install steps and other required stuff (see picostdlib) ...

## Documentation

information on Inputs / Outputs Here


## To Do

- Implement 74HC166 support
- Implement 74HC299 support
- Tests via pico debug?

## Contributing

Contributions are certainly welcome! Best place to start would probably be by 
creating an issue.



