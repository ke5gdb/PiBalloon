#!/bin/bash

while [ TRUE ] ; do
	# Sync the logs
	FILES=`ls /mnt/ramdisk/ | grep -v '.png'`
	echo $FILES
	for FILE in $FILES; do
		cat /mnt/ramdisk/$FILE | grep -v ",None" >> /var/log/balloon/$FILE
		echo -n > /mnt/ramdisk/$FILE
	done

	# Compile an APRS Packet
	#aprs -c KE5GDB-4 -o /dev/null '> Testing 1234'
	sleep 10
done
