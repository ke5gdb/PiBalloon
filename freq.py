#!/usr/bin/python

#
# Quick script to change the frequency of the DORJI module
#
# Usage: freq.py 144.3900 144.3900 0015 /dev/ttyUSBO
# 		 TX freq  RX freq  PL Tone  /dev/
# PL Tone 110.9 = 0015
#


import serial
import sys

arg = sys.argv 
ser = serial.Serial(arg[4], 9600, timeout=1)

ser.write('AT+DMOCONNECT\r\n')
print ser.readline()

ser.write('AT+DMOSETGROUP=1,' + arg[1] + ',' + arg[2] + ',' + arg[3] + ',2,' + arg[3] + '\r\n')
print ser.readline()

ser.close()
