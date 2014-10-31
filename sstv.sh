#!/bin/bash

#
# SSTV Daemon
#
# This script will grab an image from a webcam,
# compile it as an SSTV image (Martin 1 or
# Robot 36) and then transmit it using the
# Dorji module.
#

# (C) Andrew Koenig 2014

GPIO=22		# GPIO Pin
PAN=2:0:1	# Left/Right Audio R -> 2:0:1 L -> 2:1:0
TXDELAY=.5	# Time (in seconds)
CYCLE=180	# Cycle time (seconds)
#PROTOCOL=r36	# Martin 1 (m1), Robot 36 (r36), Scottie DX (sdx)
WAV=/mnt/ramdisk/image.png.wav
IMG=/mnt/ramdisk/image.png

COUNT=4

function aprs_tx() {
	# THIS IS TEMPORARY! JUST FOR DEMONSTRATION PURPOSES!
	echo Assembling packet
	aprs -c KE5GDB-4 -o /home/pi/balloon/aprs.wav "`cat /mnt/ramdisk/aprs.packet`"
	echo Transmitting packet
	echo 0 > /sys/class/gpio/gpio$GPIO/value
	sleep $TXDELAY
	mplayer /home/pi/balloon/aprs.wav -af pan=$PAN
	echo 1 > /sys/class/gpio/gpio$GPIO/value
}

while ! [ -f /mnt/ramdisk/kill_sstv ] ; do
	# Establish start time
	TIME=`date +%s`

	# Send Martin 1 every 5 images
	if [ $(($COUNT % 5)) -eq 0 ] ; then
		PROTOCOL=sdx
	else
		PROTOCOL=r36
	fi


	# Take picture
	fswebcam --top-banner --title "K5UTD High Alt. Balloon" --subtitle 'Now in technicolor!' -S 120 $IMG

	# Compile image into SSTV
	sstv -r 22050 -p $PROTOCOL $IMG

	# Transmit
	echo 0 > /sys/class/gpio/gpio$GPIO/value
	sleep $TXDELAY
	mplayer $WAV -af pan=$PAN
	echo 1 > /sys/class/gpio/gpio$GPIO/value

	# Run the APRS script
	/home/pi/balloon/freq.py 144.3900 144.3900 0015 /dev/ttyUSB0
	/home/pi/balloon/aprs.sh
	/home/pi/balloon/freq.py 144.5000 144.5000 0015 /dev/ttyUSB0

	# Counter
	COUNT=$(($COUNT + 1))

	# Sleep
	TIME=$(($(date +%s) - $TIME))
	echo Executing took $TIME seconds, iteration number $COUNT
	if [ $TIME -gt 0 ] ; then
		echo Sleeping $(($CYCLE - $TIME)) seconds...
		sleep $(($CYCLE - $TIME))
	fi
done

