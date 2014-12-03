#!/usr/bin/python

#
# Sensor polling script for PiBalloon
#
# This script also assembles the APRS packets!
#

# I'm not a CS guy

table = '/'    # Primary Symbol Table (/)
symbol = 'O'   # Jeep (j); Balloon (O)
comment = 'PiBalloonII ke5gdb@gmail.com'

# Global variables
gpsd = None

import os
import glob
import time
from decimal import Decimal
import Adafruit_BMP.BMP085 as BMP085
import Adafruit_DHT
import threading 
import Queue
import logging
from gps import *
from math import modf

# Setup the 1-wire thermal sensor
w1_base_dir = '/sys/bus/w1/devices/'
w1_device_folder = glob.glob(w1_base_dir + '28*')[0]
w1_device_file = w1_device_folder + '/w1_slave'

# Setup the BMP pressure sensor
sensor = BMP085.BMP085()


# This will read the temp by reading a file, and cutting the extra crap
def read_temp():
	lines = read_temp_raw()
	while lines[0].strip()[-3:] != 'YES':
		time.sleep(0.2)
		lines = read_temp_raw()
	equals_pos = lines[1].find('t=')
	if equals_pos != -1:
		temp_string = lines[1][equals_pos+2:]
		temp_c = float(temp_string) / 1000.0
		if temp_c != 85.0:
			return temp_c

# This actually read the file for the read_temp function
def read_temp_raw():
	f = open(w1_device_file, 'r')
	lines = f.readlines()
	f.close()
	return lines

# A very simple humidity reading function
def read_humidity():
	humidity, temperature = Adafruit_DHT.read_retry(11, 17)
	return humidity

# A function to append to logfiles in the ramdisk
def write_file(value, file):
	f = open('/mnt/ramdisk/' + file, 'a')
	f.write(value + '\n')
	f.close()

# A function to overwrite to logfiles in the ramdisk
def overwrite_file(value, file):
	f = open('/mnt/ramdisk/' + file, 'w')
	f.write(value + '\n')
	f.close()

# A loop to grab and write the temp data
def temp_loop():
	while True:
		temp = read_temp()
		if temp != None:
			output = str(round(Decimal(time.time()),2)) + ',' + str(temp)
			#print output
			write_file(output, 'temp.log')
			print "t",

# Pressure loop
def pressure_loop():
	while True:
		try:
			pressure = sensor.read_sealevel_pressure()
			output = str(round(Decimal(time.time()),2)) + ',' + str(pressure)
			#print output
			write_file(output, 'pressure.log')
			time.sleep(0.25)
			print "p",
		except:
			print "Crap!"

# Humidity loop
def humidity_loop():
	while True:
		humidity = read_humidity()
		if humidity != None and humidity != 0:
			output = str(round(Decimal(time.time()),2)) + ',' + str(humidity)
			#print output
			write_file(output, 'humidity.log')
			print "h",

def read_gps():
	global gpsd
	gpsd = gps(mode=WATCH_ENABLE)
	while True:
		gpsd.next()

# Convert lat/lon to APRS style lat/lon
def decdeg2aprs(dd,val):
	negative = dd < 0
	if val == 'lon':
		if negative:
			dir = 'W'
		else:
			dir = 'E'
	else:
		if negative:
			dir = 'S'
		else:
			dir = 'N'
  
	dd = abs(dd)
	degrees = int(dd)
	dd = dd - degrees
	minutes = round(dd*60, 2)
	b,a = modf(minutes)
	return str(degrees) + str(a).zfill(4)[:2] + '.' + str(b).ljust(4, '0')[-2:] + dir
		
def gps_loop():
	#gpsp = GPSPoller()
	#gpsp.start()
	time_set = False
	time.sleep(3)
	
	while True:
		if str(gpsd.fix.altitude) != 'nan':
			# Set system clock
			if not time_set:
				os.system(str('sudo date +%FT%T.000Z -s ' + gpsd.utc))
				time_set = True
				print "Time set",

			# GPS File logging
			output = (str(round(Decimal(time.time()),2)) + ',' + str(gpsd.fix.latitude) + ',' + str(gpsd.fix.longitude) + 
				 ',' + str(gpsd.fix.altitude) + ',' + str(gpsd.fix.track) + ',' + str(gpsd.fix.speed) + ',' + str(gpsd.fix.climb) + ',' +
				str(len(gpsd.satellites)))
			write_file(output, 'gps.log')
			
			# APRS Packet compilation
			lat = decdeg2aprs(gpsd.fix.latitude,'lat')
			lon = decdeg2aprs(gpsd.fix.longitude,'lon')
			speed = round(gpsd.fix.speed / 2.237, 1)
			climb = gpsd.fix.climb
			alt = int(gpsd.fix.altitude * 3.281)
			if alt < 0:
				alt = 0
			if gpsd.fix.track < 361:
				course = int(float(gpsd.fix.track))
			else:
				course = 0
			
			# The packet itself
			packet =  '!' + lat + table + '0' + lon.zfill(5) + symbol  + str(course).zfill(3) + '/' + str(int(speed)).zfill(3) + '/A=' + str(alt).zfill(6) + '>' + comment
			overwrite_file(packet, "aprs.packet")
			print "g",
		else:
			print "GPS not locked!",

		time.sleep(.8)

# Telemetry Loop - Records values into telemetry and status packets
def telemetry_loop():
	while True:
		time.sleep(5)
		f = open('/sys/class/thermal/thermal_zone0/temp', 'r')
		variables.tlm_cpu_temp = f.read()
		f.close()
		variables.tlm_cpu_temp = str(int(variables.tlm_cpu_temp) / 1000.0)

		variables.tlm_temp_ext = str(10 * (variables.tlm_temp_ext + 60)) 	# APRS Equation A=0 B=.1 C=-60
		variables.tlm_temp_int = str(10 * variables.tlm_temp_int)			# APRS Equation A=0 B=.1 C=0
		variables.tlm_humidity = str(variables.tlm_humidity)				# APRS Equation A=0 B=0 C=0
		variables.tlm_pressure = str(variables.tlm_pressure)				# Status; no equation
		variables.tlm_volts = str(0)	#WIP
		variables.tlm_current = str(0)	#WIP
		variables.tlm_alt = str(variables.tlm_alt)								# Status; no equation
		variables.tlm_sats = str(variables.tlm_sats)						# Status; no equation
		variables.tlm_climb = str(variables.tlm_climb)						# Status, no equation
		
		status = ('Batt: ' + variables.tlm_volts + 'v, Current: ' + variables.tlm_current + 'mA, Pressure: ' + variables.tlm_pressure + 
				 'Pa, Climb: ' + variables.tlm_climb + 'm/s, CPU Temp: ' + variables.tlm_cpu_temp + 'C, Sats: ' + variables.tlm_sats)
		overwrite_file(status, 'status.packet')
		
		telem = (variables.tlm_temp_int + ',' + variables.tlm_temp_ext + ',' + variables.tlm_humidity + ',' + variables.tlm_volts + ',' + 
				variables.tlm_current + ',000000')
		print status
		print telem
		time.sleep(2)

q = Queue.Queue()

class MasterThread:
	def __init__(self):
		self.logger=logging.getLogger("MasterThread")
		self.logger.debug("Adding Threads")
		
		self.threads=[]
		self.threads.append(threading.Thread(target=temp_loop))
		self.threads.append(threading.Thread(target=pressure_loop))
		self.threads.append(threading.Thread(target=humidity_loop))
		self.threads.append(threading.Thread(target=read_gps))
		self.threads.append(threading.Thread(target=gps_loop))

	def run(self):
		self.logger.info("Enabling all threads")

		self.logger.info("Going Polythreaded")
		for thread in self.threads:
			thread.daemon = True
			thread.start()

	        #we need this thread to keep ticking
		while(True):
			if not any([thread.isAlive() for thread in self.threads]):
				print  "Thread dead!"
				break
			else:
				time.sleep(1)

		self.logger.info("All threads have terminated, exiting main thread...")

if __name__=="__main__":
	logging.basicConfig(level=logging.WARNING)
	threadCore = MasterThread()
	threadCore.run()
