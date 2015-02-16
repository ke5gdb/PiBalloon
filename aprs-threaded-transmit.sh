#!/bin/bash

#
# APRS Position, Telemetry and Status Packet Compiler/Transmitter
#
# Requires Python libafsk (pip install afsk)
#


GPIO=/sys/class/gpio/gpio22/value
PAN=2:0:1

# Long term counter
COUNT=`cat /home/pi/balloon/.count`

# On the second iteration, send the telemetry parameters
if [ $COUNT -eq 1 ] ; then
	echo -n "Compiling/sending telemetry units, parameters, etc... "
	aprs -c KE5GDB -o aprs.wav ":KE5GDB-4 :PARM.ExtTemp,IntTemp,Humidity,Current,Voltage"
	echo 0 > $GPIO
	mplayer /home/pi/balloon/aprs.wav -af pan=$PAN > /dev/null 2>&1
	echo 1 > $GPIO

	aprs -c KE5GDB -o aprs.wav ":KE5GDB-4 :UNIT.degC,degC,%,mA,Volts"
	echo 0 > $GPIO
	mplayer /home/pi/balloon/aprs.wav -af pan=$PAN > /dev/null 2>&1
	echo 1 > $GPIO

	aprs -c KE5GDB -o aprs.wav ":KE5GDB-4 :EQNS.0,.1,-60,0,.1,-60,0,.1,0,0,2,0,0,.01,5"
	echo 0 > $GPIO
	mplayer /home/pi/balloon/aprs.wav -af pan=$PAN > /dev/null 2>&1
	echo 1 > $GPIO

	echo "done!"
fi

sleep 2

echo -n "Transmitting position packet... "
echo 0 > $GPIO
mplayer /home/pi/balloon/position.wav -af pan=$PAN > /dev/null 2>&1
echo 1 > $GPIO
echo "done!"

sleep 2

echo -n "Transmitting telemetry packet... "
echo 0 > $GPIO
mplayer /home/pi/balloon/telem.wav -af pan=$PAN > /dev/null 2>&1
echo 1 > $GPIO
echo "done!"

sleep 2

echo -n "Transmitting status packet... "
echo 0 > $GPIO
mplayer /home/pi/balloon/status.wav -af pan=$PAN > /dev/null 2>&1
echo 1 > $GPIO
echo "done!"
