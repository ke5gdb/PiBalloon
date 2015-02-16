#!/bin/bash

#
# APRS Position, Telemetry and Status Packet Compiler/Transmitter
#
# Requires Python libafsk (pip install afsk)
#


GPIO=/sys/class/gpio/gpio22/value
PAN=2:0:1

# Compile an APRS position packet (packet assembled in sensor_logging.py)
echo -n "Compiling position packet... "
aprs -c KE5GDB-4 -d KE5GDB -o /home/pi/balloon/position.wav "`cat /mnt/ramdisk/aprs.packet`"
echo "done!"

###########
# OKAY
# I TOLD MYSELF NOT TO DO THIS IN BASH
# BUT PYTHON DOESN'T WANT TO PLAY NICE WITH GLOBAL VARIABLES!
# SO I'M SCRAPING SENSOR LOGS FOR TELEMETRY DATA.
# OKAY?
###########

# Long term counter
COUNT=`cat /home/pi/balloon/.count`
if [[ $COUNT -gt 999 ]] ; then
	echo "Counter at 999! Starting back at 1"
	COUNT=0
fi
echo $(($COUNT + 1)) > /home/pi/balloon/.count

# Zero-fill the counter (APRS spec)
COUNT=`printf "%03d\n" $COUNT`

# Scrape these parameters from the sensor logs
TLM_TEMP_EXT=`tail -1 /mnt/ramdisk/temp.log | cut -d',' -f2`
TLM_TEMP_INT=`tail -1 /mnt/ramdisk/tmp513.log | cut -d',' -f4`
TLM_HUMIDITY=`tail -1 /var/log/balloon/humidity.log | cut -d',' -f2`
TLM_CURRENT=`tail -1 /mnt/ramdisk/tmp513.log | cut -d',' -f7`
TLM_TXCURRENT=`tail -1 /mnt/ramdisk/tmp513.log | cut -d',' -f8`
TLM_VOLTAGE=`tail -1 /mnt/ramdisk/tmp513.log | cut -d',' -f2`
TLM_PRESSURE=`tail -1 /mnt/ramdisk/pressure.log | cut -d',' -f2`
TLM_CPU_TEMP=`echo "$(cat /sys/class/thermal/thermal_zone0/temp) * .001" | bc`
TLM_SATS=`tail -1 /mnt/ramdisk/gps.log | cut -d',' -f8`

# Assemble the status packet
STATUS=">Batt Volts: $TLM_VOLTAGE, Idle Current: $TLM_CURRENT mA, Pressure: $TLM_PRESSURE Pa,"
STATUS="$STATUS  TX Current: $TLM_TXCURRENT mA, CPU Temp: $TLM_CPU_TEMP C, Sats: $TLM_SATS"

# Scale the telemetry values to 0-999 (almost 10-bit res...)
TLM_TEMP_EXT=`printf "%.0f" $(echo "($TLM_TEMP_EXT + 60) / .1" | bc)` # A=0 B=.1 C=-60
TLM_TEMP_INT=`printf "%.0f" $(echo "($TLM_TEMP_INT + 60) * 10" | bc)` # A=0 B=.1 C=-60
TLM_HUMIDITY=`printf "%.0f" $(echo "($TLM_HUMIDITY * 10)" | bc)` # A=0 B=.1 C=0
TLM_CURRENT=`printf "%.0f" $(echo "($TLM_CURRENT * .5)" | bc)` # A=0 B=2 C=0
TLM_VOLTAGE=`printf "%.0f" $(echo "($TLM_VOLTAGE - 5) * 100" | bc)` # A=0 B=.01 C=5

if [ "$TLM_HUMIDITY" = "0" ] ; then
	TLM_HUMIDITY=
fi

# Assemble the telemetry packet
# T#123,234,345,456,567,678,01010101 Counter, then5  values
TELEM=T#$COUNT,$TLM_TEMP_EXT,$TLM_TEMP_INT,$TLM_HUMIDITY,$TLM_CURRENT,$TLM_VOLTAGE,00000000

# Compile an APRS telemetry packet
echo -n "Compiling telemetry packet... "
aprs -c KE5GDB-4 -d KE5GDB -o /home/pi/balloon/telem.wav "$TELEM"
echo "done!"

# Compile an APRS status packet
echo -n "Compiling status packet... "
aprs -c KE5GDB-4 -d KE5GDB -o /home/pi/balloon/status.wav "$STATUS"
echo "done!"

# Sync the logs; saved for last due to scrapers
sudo chmod 777 -R /mnt/ramdisk/
FILES=`ls /mnt/ramdisk/ | grep -v '.png'`
#echo $FILES
for FILE in $FILES; do
	cat /mnt/ramdisk/$FILE | grep -v ",None" >> /var/log/balloon/$FILE
	echo -n > /mnt/ramdisk/$FILE
done

echo $TELEM
echo $STATUS
echo Count: $COUNT
