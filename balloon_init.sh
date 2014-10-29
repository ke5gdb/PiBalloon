#!/bin/bash

# This script sets up GPIO and triggers the scripts

BALLOON=/home/pi/balloon

if [ `whoami` != "root" ] ; then
	echo "This must be run as root!"
	exit 1
fi

killall gpsd

sleep 1

gpsd /dev/ttyUSB1

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

sleep 5

# Okay, this command is shitty, but I'd prefer to do a screen -r as pi

sudo -u pi screen -dmS sensor sudo $BALLOON/sensor_logging.py
