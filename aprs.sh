#!/bin/bash

GPIO=/sys/class/gpio/gpio22/value
PAN=2:0:1

# Compile an APRS position packet
aprs -c KE5GDB-4 -o /home/pi/balloon/aprs.wav "`cat /mnt/ramdisk/aprs.packet`"
echo 0 > $GPIO
mplayer /home/pi/balloon/aprs.wav -af pan=$PAN
echo 1 > $GPIO

###########
# OKAY
# I TOLD MYSELF NOT TO DO THIS IN BASH
# BUT PYTHON DOESN'T WANT TO PLAY NICE WITH GLOBAL VARIABLES!
# SO I'M SCRAPING SENSOR LOGS FOR TELEMETRY DATA. 
# OKAY?
###########

# Long term counter
COUNT=`cat /home/pi/balloon/.count`
echo $(($COUNT + 1)) > /home/pi/balloon/.count
COUNT=`printf "%03d\n" $COUNT`
TLM_TEMP_EXT=`tail -1 /mnt/ramdisk/temp.log | cut -d',' -f2`
TLM_TEMP_INT=25.123 #`tail -1 /mnt/ramdisk/temp.log | cut -d',' -f3`
TLM_HUMIDITY=`tail -1 /mnt/ramdisk/humidity.log | cut -d',' -f2`
TLM_CURRENT=2.1234 #`tail -1 /mnt/ramdisk/power.log | cut -d',' -f3`
TLM_VOLTAGE=13.8212 #`tail -1 /mnt/ramdisk/power.log | cut -d',' -f2`
TLM_PRESSURE=`tail -1 /mnt/ramdisk/pressure.log | cut -d',' -f2`
TLM_CPU_TEMP=`echo "$(cat /sys/class/thermal/thermal_zone0/temp) * .001" | bc`
TLM_SATS=`tail -1 /mnt/ramdisk/gps.log | cut -d',' -f8`

STATUS="Volt: $TLM_VOLTAGE, Current: $TLM_CURRENT, Pressure: $TLM_PRESSURE Pa,"
STATUS="$STATUS  Ascent: $TLM_ASCENT m/s, CPU Temp: $TLM_CPU_TEMP, Sats: $TLM_SATS"

TLM_TEMP_EXT=`printf "%.0f" $(echo "($TLM_TEMP_EXT + 60) / .1" | bc)` # A=0 B=.1 C=-60
TLM_TEMP_INT=`printf "%.0f" $(echo "($TLM_TEMP_INT + 60) * 10" | bc)` # A=0 B=.1 C=-60
TLM_HUMIDITY=`printf "%.0f" $(echo "($TLM_HUMIDITY * 10)" | bc)` # A=0 B=.1 C=0
TLM_CURRENT=`printf "%.0f" $(echo "($TLM_CURRENT * 400)" | bc)` # A=0 B=.0025 C=0
TLM_VOLTAGE=`printf "%.0f" $(echo "($TLM_VOLTAGE - 5) * 100" | bc)` # A=0 B=.01 C=5
TELEM=T#$COUNT,$TLM_TEMP_EXT,$TLM_TEMP_INT,$TLM_HUMIDITY,$TLM_CURRENT,$TLM_VOLTAGE,00000000

# Compile an APRS telemetry packet
aprs -c KE5GDB-4 -o /home/pi/balloon/aprs.wav "$TELEM"
echo 0 > $GPIO
mplayer /home/pi/balloon/aprs.wav -af pan=$PAN
echo 1 > $GPIO

# Compile an APRS status packet 
aprs -c KE5GDB-4 -o /home/pi/balloon/aprs.wav "$STATUS"
echo 0 > $GPIO
mplayer /home/pi/balloon/aprs.wav -af pan=$PAN
echo 1 > $GPIO

# Sync the logs
sudo chmod 777 -R /mnt/ramdisk/
FILES=`ls /mnt/ramdisk/ | grep -v '.png'`
echo $FILES
for FILE in $FILES; do
	cat /mnt/ramdisk/$FILE | grep -v ",None" >> /var/log/balloon/$FILE
	echo -n > /mnt/ramdisk/$FILE
done

echo $TELEM
echo $STATUS