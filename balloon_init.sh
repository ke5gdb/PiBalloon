#!/bin/bash

# This script sets up GPIO and triggers the scripts

BALLOON=/home/pi/balloon

if [ `whoami` != "root" ] ; then
	echo "This must be run as root!"
	exit 1
fi

killall gpsd

SERIAL=`$BALLOON/freq.py 144.5000 144.5000 0015 /dev/ttyUSB0 | grep "+DMOSETGROUP:0"`
if [ "$SERIAL" != "" ] ; then 
	echo /dev/ttyUSB0 > $BALLOON/.radio
	gpsd /dev/ttyUSB1
else
	echo /dev/ttyUSB1 > $BALLOON/.radio
	gpsd /dev/ttyUSB0
fi

chmod 777 $BALLOON/.radio

modprobe w1-gpio pullup=1
modprobe w1-therm strong_pullup=1

if [[ `ls /sys/class/gpio/ | grep gpio22` = "" ]] ; then
	echo 22 > /sys/class/gpio/export
	echo out > /sys/class/gpio/gpio22/direction
	echo 1 > /sys/class/gpio/gpio22/value
else
	echo "GPIO22 already exists!"
fi

if [[ `ls /sys/class/gpio/ | grep gpio23` = "" ]] ; then
	echo 23 > /sys/class/gpio/export
	echo out > /sys/class/gpio/gpio23/direction
	echo 1 > /sys/class/gpio/gpio23/value
else
	echo "GPIO23 already exists!"
fi

sudo -u pi echo 0 > /home/pi/balloon/.count
chmod 777 /home/pi/balloon/.count

sleep 5

# Okay, this command is shitty, but I'd prefer to do a screen -r as pi

sudo -u pi screen -dmS sensor sudo $BALLOON/sensor_logging.py
sudo -u pi screen -dmS tmp513 sudo $BALLOON/tmp513_logging.py

sleep 10

sudo -u pi screen -dmS sstv $BALLOON/sstv-threaded.sh
