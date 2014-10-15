#!/usr/bin/python

#
# Quick script to change the frequency of the DORJI module
#

import serial
import sys


arg = sys.argv 
ser = serial.Serial('/dev/ttyUSB0', 9600, timeout=1)

ser.write('AT+DMOCONNECT\r\n')
print ser.readline()

ser.write('AT+DMOSETGROUP=1,' + arg[1] + ',' + arg[2] + ',' + arg[3] + ',2,' + arg[3] + '\r\n')
print ser.readline()

ser.close()
