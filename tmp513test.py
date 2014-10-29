#!/usr/bin/python

# read TI TMP512/TMP513 over I2C
# Jens Jensen AF5MI 2014

import wiringpi2 as wp
import time

# i2c address of device - see datasheet, assumes A0 = SCL.
ADDR = 0x5D

# current calibration register, see datasheet for calc
# I = (V_shunt * CalReg) / 4096
ICAL = 40960  # R_shunt = 0.01 ohms, I in 0.1 mA
PR_mW = 2.0 # PR multiplier per LSB to get mW result
CR_mA = 0.1 # CR multiplier per LSB to get mA result

CONFREG1 = 0b0000100110011111  # config reg 1 - see datasheet

CFGREG1 = 0x00 # shunt config
CFGREG2 = 0x01 # temp config
STATUSREG = 0x02
SMBUSCTLREG = 0x03
SVR  = 0x04  # shunt voltage result, 10uV LSB
BVR  = 0x05  # bus voltage result, 4mV LSB
PR   = 0x06  # power measurement result
CR   = 0x07  # current measurement result
LTR  = 0x08  # local temp result register
RTR1 = 0x09  # remote temp result 1 register
RTR2 = 0x0A  # remote temp result 2 register
RTR3 = 0x0B  # remote temp result 3 register
SCR  = 0x15  # shunt calibration register

RTS1_NFACTOR = 0x16  # n-Factor 1 Register 16h (r/w)
RTS2_NFACTOR = 0x17  # n-Factor 2 Register 17h (r/w)
RTS3_NFACTOR = 0x18  # n-Factor 3 Register 18h (r/w)

def fromSignedInt16(num):
   # convert signed int16 to python int
   if ( num > 32768):
		num = num - 65535
   return num
 
def getRegRaw (fd, reg):
    data = wp.wiringPiI2CReadReg16(fd, reg)
    data = data >> 8 | ((data << 8) & 0xffff) # byte order fix
    return fromSignedInt16(data)

def getTempC (fd, reg):
    # valid range: +/-256C
    raw = getRegRaw(fd, reg)
    diodeOpen = raw & 0x01
    tempC = (raw >> 3) * 0.0625
    if (diodeOpen):
        # invalid reading
        tempC = -999 
    return tempC

def tempCtoF (tempC):
    tempF = (tempC * 9.0) / 5.0 + 32.0
    if (tempC > -256):
    	return tempF
    else:
      return -999

def busVoltageResult (bvrraw):
    busVoltage = (bvrraw >> 3) * 0.004
    return busVoltage

# setup i2c
fd = wp.wiringPiI2CSetup(ADDR)
if ( fd < 0):
    print "I2CSetup Failed, ERR: %d" % fd
    exit(1)

# init current calibration register
caldata = ICAL >> 8 | ((ICAL << 8) & 0xffff) # byte order fix
wp.wiringPiI2CWriteReg16(fd, SCR, caldata)

# write config register
#cfgregdata = CONFREG1 >> 8 | ((CONFREG1 << 8) & 0xffff)
#wp.wiringPiI2CWriteReg16(fd, CFGREG1, cfgregdata)

# get data loop
while True:
    ltrTempF = tempCtoF(getTempC(fd, LTR))
    rtr1TempF = tempCtoF(getTempC(fd, RTR1))
    rtr2TempF = tempCtoF(getTempC(fd, RTR2))
    rtr3TempF = tempCtoF(getTempC(fd, RTR3))
    bvrVal = getRegRaw(fd, BVR)
    busVoltage = busVoltageResult(bvrVal)
    svrVal = getRegRaw(fd, SVR)
    pwrVal = getRegRaw(fd, PR) * PR_mW 
    curVal = getRegRaw(fd, CR) * CR_mA

    print("LTemp: %3.1f F RT1: %3.1f F RT2: %3.1f F RT3: %3.1f F" %
         (ltrTempF, rtr1TempF, rtr2TempF, rtr3TempF))
    print("Vbus: %2.2f Vdc P: %3d mW I: %3d mA" % 
          (busVoltage, pwrVal, curVal))
    #print
    #time.sleep(2)


