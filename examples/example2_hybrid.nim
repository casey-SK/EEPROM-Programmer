import picostdlib/[gpio]
import picostdlib, eeprom
import bitops, tables
  
stdioInitAll()

let pinMap = {
  IO0: 15.Gpio,
  IO1: 14.Gpio,
  IO2: 13.Gpio,
  IO3: 20.Gpio,
  IO4: 21.Gpio,
  IO5: 22.Gpio,
  IO6: 26.Gpio,
  IO7: 27.Gpio,
  WE: 19.Gpio
  }.toTable

let shiftMap = { 
  A0: 0, 
  A1: 1, 
  A2: 2, 
  A3: 3, 
  A4: 4, 
  A5: 5, 
  A6: 6, 
  A7: 7, 
  A8: 8, 
  A9: 9,
  A10: 10,
  OE: -1
  }.toTable

let
  dataPin = 16.Gpio # Green
  clockPin = 18.Gpio # Yellow
  latchPin = 17.Gpio # White
  bytes = 2

let shiftPins = ShiftPins(data: dataPin, clock: clockPin, latch: latchPin, shifterBytes: bytes)

let x = newEEPROM(pinMap, shiftMap, shiftPins)

let address = 0b0
let data = 43
# LSB FIRST

print("\n")
sleep(5000)
print("\n")
sleep(1000)
print("\n")
writeEEPROM(x, address, data)
print($readEEPROM(x, address))