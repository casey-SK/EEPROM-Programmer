import picostdlib/[gpio]
import picostdlib
import advancedIO, bitops, strutils, tables, sequtils, math

type 
  EEPROM_Pins* = enum
    ## Supports 28C16 (2K * 8 bits), through to 28C512 (64K * 8 bits). \n
    ## So, many address options are supported, but IO and CE,OE, and WE are fixed.
    ## Not all EEPROMs in this range have been tested to work, use at your own risk.
    A0, A1, A2, A3, A4, A5, A6, A7, A8, A9, A10, A11, A12, A13, A14, A15
    IO0, IO1, IO2, IO3, IO4, IO5, IO6, IO7,
    CE, OE, WE
  
  SetupKind* = enum
    pinsOnly, shiftOnly, hybrid
  
  ShiftPins* = ref object
    data*, clock*, latch*: Gpio
    shifterBytes*: int # a.k.a how many shift registers are you using?
  
  EEPROM* = object
    # unfortunately, case variants will not work here :(
    addressPins*: Table[EEPROM_Pins, Gpio] # A0 .. An-1
    addressSetup*: SetupKind # is it all dedicated pins, shift register, hybrid?
    dataPins*: Table[EEPROM_Pins, Gpio] # IO0 .. IO7
    dataSetup*: SetupKind # is it all dedicated pins, shift register, hybrid?
    outputEnable*: Gpio
    writeEnable*: Gpio
    chipEnable*: Gpio
    shiftMap*: Table[EEPROM_Pins, int]
    shiftPins*: ShiftPins
  
  outputType* = enum
    Binary, Hex, Decimal


const 
  addresses: seq[EEPROM_Pins] = @[A0, A1, A2, A3, A4, A5, A6, A7, A8, A9, A10,  
                                  A11,A12, A13, A14, A15]
    ## When defining a new EEPROM, defined address pins must be a continous 
    ## subset of the the address array. From A0 .. An
  dataLines: seq[EEPROM_Pins] = @[IO0, IO1, IO2, IO3, IO4, IO5, IO6, IO7]
    ## When defining a new EEPROM, defined data pins must be exactly equal to
    ## the dataLines array.
  enablers: seq[EEPROM_Pins] = @[OE, WE, CE]


proc validateEEPROM(pinMap: Table[EEPROM_Pins, Gpio] = initTable[EEPROM_Pins, Gpio]();
               shiftMap: Table[EEPROM_Pins, int] = initTable[EEPROM_Pins, int]();
               shiftPins: ShiftPins = ShiftPins()) =
  ## Ensure all pins are properly defined as follows:
  ## - Address Pins: should have an A0, and be continuous from A0 to An
  ## - Data Pins: should be the continous range A0 .. A7
  ## - OE, WE: Must be defined (chip enable can be optionally defined)
  ## 
  ## These Pins can exist either in the pinMap table or the shiftMap table.
  ## 
  ## Additionally, shiftPins is checked to ensure all values are defined.

  # --- CHECK ADDRESS DEFINITIONS ---
  
  # create list from both sources
  var addressList: seq[EEPROM_Pins]
  for i in addresses:
    if i in pinMap:
      addressList.add(i)
    if i in shiftMap:
      addressList.add(i)
  
  # check to ensure A0 is defined
  if not (A0 in addressList):
    echo "Address Pin A0 not defined!"
    quit(1)
  
  # check that the list length is equal to the max address pin
  # it is assumed that the user didn't forget to define the last pin.
  if addressList.len() != (int(addressList.max()) + 1):
    echo "There is a dicontinuity in defined address pins"
    quit(1)

  # since we know the length of the list is appropriate, we just need to ensure
  #   none of the values are duplicates
  if addressList != addressList.deduplicate():
    echo "There are duplicates in the defined address pins"
    quit(1)
  
  # --- CHECK DATA PINS ---

  # create list from both sources
  var dataList: seq[EEPROM_Pins]
  for i in dataLines:
    if i in pinMap:
      dataList.add(i)
    if i in shiftMap:
      dataList.add(i)
  
  # check that dataList exactly matches defined constant
  if dataList != dataLines:
    echo "Incorrectly defined data pins, should be IO0 .. IO7 (without duplicates or gaps)"
    quit(1)

  # --- CHECK OE AND WE PINS ---

  if not (OE in pinMap or OE in shiftMap):
    echo "Output Enable pin not defined"
    quit(1)

  if not (WE in pinMap or WE in shiftMap):
    echo "Write Enable pin not defined"
    quit(1)
  
  # --- CHECK SHIFT PINS (IF APPLICABLE) ---

  # we only need to check shift pins if eeprom pins have been mapped using a shiftMap
  if shiftMap.len != 0:
    var pins: seq[Gpio]
    pins.add(shiftPins.data)
    pins.add(shiftPins.clock)
    pins.add(shiftPins.latch)

    if pins != pins.deduplicate():
      echo "shiftPins (clock, data, latch) must be unique"
      quit(1)
    
    if shiftPins.shifterBytes > 4 or shiftPins.shifterBytes < 1:
      echo "invalid number of shifterBytes. Should be between 1 and 4, inclusive"
      quit(1)
  

proc newEEPROM*(pinMap: Table[EEPROM_Pins, Gpio] = initTable[EEPROM_Pins, Gpio]();
               shiftMap: Table[EEPROM_Pins, int] = initTable[EEPROM_Pins, int]();
               shiftPins: ShiftPins = ShiftPins()): EEPROM =
  ## Create a new Parallel EEPROM <---> RP2040 mapped object.
  ## 
  ## if using only dedicated pins (no shift register), only one table needs to
  ## be defined, mapping the pins on the Pico to the pins on the EEPROM
  ## 
  ## otherwise, if using a shift register, a table needs to be provided defining
  ## the position of each input pin along the shift register(s). 
  ## - Position 0 is the MSB (the last bit to be shifted out)
  ## - Backwards indexs can be used, ex. OE: -1 corresponds to the last bit
  ##   in the last shift register byte
  ## 
  ## A hybrid of dedicated pins and shift register(s) can be used. NOTE: 
  ## PARALLEL TO SERIAL shiftIn() not currently supported.
  ## 
  validateEEPROM(pinMap, shiftMap, shiftPins)
  var x: EEPROM
  var shifter, discrete: bool
  # build addressPins and addressSetup
  for i in addresses:
    if i in pinMap:
      discrete = true
      discard x.addressPins.hasKeyorPut(i,pinMap[i])
    if i in shiftMap:
      shifter = true
      discard x.addressPins.hasKeyOrPut(i,shiftPins.data)

  if shifter and discrete: 
    x.addressSetup = hybrid
    x.shiftMap = shiftMap
    x.shiftPins = shiftPins
  elif shifter:
    x.addressSetup = shiftOnly
    x.shiftMap = shiftMap
    x.shiftPins = shiftPins
  else:
    x.addressSetup = pinsOnly
  
  # build dataPins and dataSetup
  shifter = false
  discrete = false
  for i in dataLines:
    if i in pinMap:
      discrete = true
      discard x.dataPins.hasKeyorPut(i,pinMap[i])
    if i in shiftMap:
      shifter = true
      x.shiftMap = shiftMap
      x.shiftPins = shiftPins
      discard x.dataPins.hasKeyOrPut(i,shiftPins.data)

  if shifter and discrete: 
    x.dataSetup = hybrid
    x.shiftMap = shiftMap
    x.shiftPins = shiftPins
  elif shifter:
    x.dataSetup = shiftOnly
    x.shiftMap = shiftMap
    x.shiftPins = shiftPins
  else:
    x.dataSetup = pinsOnly
  
  # build enable pins
  for i in enablers:
    if i in pinMap:
      if i == OE: x.outputEnable = pinMap[i] 
      elif i == WE: x.writeEnable = pinMap[i] 
      elif i == CE: x.chipEnable = pinMap[i] 
    if i in shiftMap:
      if i == OE: x.outputEnable = shiftPins.data
      elif i == WE: x.writeEnable = shiftPins.data
      elif i == CE: x.chipEnable = shiftPins.data
      x.shiftMap = shiftMap
      x.shiftPins = shiftPins
  return x
  

proc setInputs(eeprom: EEPROM; address: SomeInteger; oe, we, ce = false) = 
  ## Set the defined input pins on the EEPROM using the given parameters.
  ## 
  ## An address must always be provided.
  ## 
  ## Supports BOTH dedicated pins and shift registers for all possible inputs.
  ## 
  ## Note that if enable parameters are set to true, then they will be set Low, 
  ## (i.e. turned on)
  ## 
  
  # check if address is out of range
  # if A0 .. An, then address must be =< to 2^(n+1)
  if address > (2 ^ eeprom.addressPins.len()) or address < 0:
    echo "address is not within range of A0 .. An"
  
  # if inputs are defined using pin's set them to their corresponding value
  if eeprom.addressSetup == pinsOnly or eeprom.addressSetup == hybrid:
    for key,value in eeprom.addressPins:
      if not(key in eeprom.shiftMap):
        eeprom.addressPins[key].init()
        eeprom.addressPins[key].setDir(Out)
        if testBit(address, int(key)):
          eeprom.addressPins[key].put(High)
        else:
          eeprom.addressPins[key].put(Low)
    
    # if the enable pins are not in the shiftMap, and enable parameter is true,
    # then initialize the pin and set to "off" state, then pulse Low to High
    if not (OE in eeprom.shiftMap):
      eeprom.outputEnable.init()
      eeprom.outputEnable.put(High)
      eeprom.outputEnable.setDir(Out)
      if oe: eeprom.outputEnable.put(Low)
      else: eeprom.outputEnable.put(High) # Sanity Check
    if not (WE in eeprom.shiftMap):
      eeprom.writeEnable.init()
      eeprom.writeEnable.put(High)
      eeprom.writeEnable.setDir(Out)
      if we: eeprom.chipEnable.put(Low)
      else: eeprom.chipEnable.put(High)
    if not (CE in eeprom.shiftMap):
      eeprom.chipEnable.init()
      eeprom.chipEnable.put(High)
      eeprom.chipEnable.setDir(Out)
      if ce: eeprom.chipEnable.put(Low)
      else: eeprom.chipEnable.put(High) 
  
  if eeprom.addressSetup == shiftOnly or eeprom.addressSetup == hybrid:
    # initialize shift pins
    eeprom.shiftPins.data.init()
    eeprom.shiftPins.clock.init()
    eeprom.shiftPins.latch.init()
    eeprom.shiftPins.data.setDir(Out)
    eeprom.shiftPins.clock.setDir(Out)
    eeprom.shiftPins.latch.setDir(Out)

    # create word that will be sent to the shiftOut(), which takes in 
    # address, ce, and we and maps their values corresponding to their positions
    # on the shift register(s), using the defined shift map.
    var word, pos: int
    let max = (eeprom.shiftPins.shifterBytes * 8) - 1
    # set address bits in word
    for key, value in eeprom.addressPins:
      if key in eeprom.shiftMap:
        pos = eeprom.shiftMap.getOrDefault(key, 0)
        if pos >= 0:
          if address.testBit(int(key)):
            word.setBit(max - pos)
          else:
            word.clearBit(max - pos)
        else:
          # users can map pins using a backwards index (such as OE: -1)
          if address.testBit(int(key)):
            word.setBit(pos * -1)
          else:
            word.clearBit(pos * -1)

    # set enable bits in word       
    if OE in eeprom.shiftMap:
      if eeprom.shiftMap[OE] >= 0:
        if oe: word.clearBit(eeprom.shiftMap[OE])
        else: word.setBit(eeprom.shiftMap[OE])
      else: # if OE is mapped using a backword index:
        if oe: word.clearBit((eeprom.shiftMap[OE] * -1) - 1)
        else: word.setBit((eeprom.shiftMap[OE] * -1) - 1)
    if WE in eeprom.shiftMap:
      if eeprom.shiftMap[WE] >= 0:
        if we: word.clearBit(eeprom.shiftMap[WE])
        else: word.setBit(eeprom.shiftMap[WE])
      else: # if WE is mapped using a backword index:
        if we: word.clearBit((eeprom.shiftMap[WE] * -1) - 1)
        else: word.setBit((eeprom.shiftMap[WE] * -1) - 1)
    if CE in eeprom.shiftMap:
      if eeprom.shiftMap[CE] >= 0:
        if ce: word.clearBit(eeprom.shiftMap[CE])
        else: word.setBit(eeprom.shiftMap[CE])
      else: # if CE is mapped using a backword index:
        if ce: word.clearBit((eeprom.shiftMap[CE] * -1) - 1)
        else: word.setBit((eeprom.shiftMap[CE] * -1) - 1)
    
    # with a word built using the inputs, we convert the word to the appropriate
    # uint size, which makes things easier for shiftOut()
    # The user has defined the number of shift registers they are using via
    # shiftPins.shifterBytes
    # we then send it out to shiftOut() which will send the Least Significant
    # Bit out first (so it will be at the farthest point from the shift in pin)
    if eeprom.shiftPins.shifterBytes == 1:
      var output = uint8(word)
      shiftOut(eeprom.shiftPins.data, eeprom.shiftPins.clock, output)
      eeprom.shiftPins.latch.pulse()
    elif eeprom.shiftPins.shifterBytes == 2:
      var output = uint16(word)
      shiftOut(eeprom.shiftPins.data, eeprom.shiftPins.clock, output)
      eeprom.shiftPins.latch.pulse()
    elif eeprom.shiftPins.shifterBytes == 3:
      # since there is no 24 bit datatype, we use a combination
      var outputLower = uint16(word)
      var outputUpper = uint8(address shr 16)
      shiftOut(eeprom.shiftPins.data, eeprom.shiftPins.clock, outputLower)
      eeprom.shiftPins.latch.pulse()
      shiftOut(eeprom.shiftPins.data, eeprom.shiftPins.clock, outputUpper)
      eeprom.shiftPins.latch.pulse()
    elif eeprom.shiftPins.shifterBytes == 4:
      var output = uint32(word)
      shiftOut(eeprom.shiftPins.data, eeprom.shiftPins.clock, output)
      eeprom.shiftPins.latch.pulse()
    else:
      echo "invalid number of shift registers"
      quit(1)


proc writeEEPROM*(eeprom: EEPROM; address, data: SomeInteger) = 
  ## Writes the 8 least significant bits of data to the EEPROM at the given 
  ## address.
  ## 
  
  sleep(10)
  
  # set the address lines for reading
  setInputs(eeprom, address, oe = false, we = false)

  # write data to EEPROM, using dedicated pins only !!!
  # TODO: support hybrid and shiftOnly (using 74HC166 PISO shift register)
  for key, value in eeprom.dataPins:
    value.init()
    value.setDir(Out)
    if data.testBit(int(key) - 16):
      value.put(High)
    else:
      value.put(Low)
  
  # Pulse the write enable pin, which is either dedicated or in the shiftMap
  sleep(10)
  setInputs(eeprom, address, oe = false, we = true)
  sleep(2)
  setInputs(eeprom, address, oe = false, we = false)
  sleep(10)


proc readEEPROM*(eeprom: EEPROM, address: SomeInteger): byte = 
  ## Read a byte of data at a specified address from an EEPROM
  
  # TODO: support 74HC166 PISO shift register. (Parallel In, Serial Out)
  #       currently we can only do SIPO shifting

  sleep(10)
  setInputs(eeprom, address, oe=true, we = false) # outputEnable = true
  
  var data: byte

  # without PISO shift support, this is the only option
  if eeprom.dataSetup == pinsOnly:
    for key, value in eeprom.dataPins:
      eeprom.dataPins[key].init()
      eeprom.dataPins[key].setDir(In)
      if eeprom.dataPins[key].get() == High:
        data.setBit(int(key) - 16) # -16 comes from EEPROM_Pins enum
      else:
        data.clearBit((int(key) - 16)) # -16 comes from EEPROM_Pins enum

  elif eeprom.dataSetup == hybrid or eeprom.dataSetup == shiftOnly:
    echo "shift-in of data values currently not supported"
    quit(1)

  # again, should be setInputs
  setInputs(eeprom, address, oe = false, we = false) # Set OE back to false
  sleep(10)
  return data


proc printConent*(eeprom:EEPROM, address: SomeInteger, outputType = Binary) =
  ## Prints the contents of a specified address in an EEPROM. The user can 
  ## specify the output to be Binary (default), Hexadecimal, or Decimal
  discard

proc printAllContents*(eeprom:EEPROM, outputType = Binary, maxWidth = 80) = 
  ## Prints the contents of every address in the EEPROM to Stdout (which 
  ## can be seen on a serial monitor) in either Binary (default), Hexadecimal, 
  ## or Decimal.
  ## 
  ## The user may also specify the maximum width of the output, to match 
  ## display conditions.
  ## 
  print("\n")
  sleep(500)
  print("\n")

  for i in countup(0, ((2 ^ eeprom.addressPins.len()) - 1), 4):
    var
      data1 = readEEPROM(eeprom, i)
      data2 = readEEPROM(eeprom, (i + 1))
      data3 = readEEPROM(eeprom, (i + 2))
      data4 = readEEPROM(eeprom, (i + 3))

    print(toBin(int(data1), 8))
    print("    ")
    print((toBin(int(data2), 8)))
    print("    ")
    print((toBin(int(data3), 8)))
    print("    ")
    print((toBin(int(data4), 8)))
    print("\n")




