# Package

version       = "0.1.5"
author        = "Casey"
description   = "EEPROM Programmer using Raspberry Pi Pico and the Nim Programming Language"
license       = "MIT"
srcDir        = "src"

skipDirs = @["examples, csource, bin"]

# Dependencies

requires "nim >= 1.2.0"
requires "https://github.com/beef331/picostdlib >= 0.2.6"
requires "https://github.com/casey-SK/Pico-Advanced-IO >= 0.2.4"