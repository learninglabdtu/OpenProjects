#!/bin/sh

WEBSITE="podcast.llab.dtu.dk"

LOGFILE="/home/pi/scriptlog"
CHROMEPID=-1

# Kill other instances
kill $(pidof -x -o '%PPID' $0) >/dev/null 2>&1
killall -9 chrome >/dev/null 2>&1
killall -9 unclutter >/dev/null 2>&1

# Set timeout on mousepointer
unclutter -noevents -grab -idle 1 &

# Prevent screen from blanking
xset -dpms
xset s off

while [ 1 ]
do
	for i in {1..10}
	do
		curl -I ${WEBSITE} >/dev/null 2>&1
		RET=$?
		if [ $RET -eq 0 ]; then
			break
		else
			echo "No connection to host, try "$i
		fi
	done
	if [ $RET -eq 0 ] then
		while [ 1 ]
			kill -0 $CHROMEPID
			if [ $? -ne 0  -o $CHROMEPID -eq -1 ]; then
				chrome --user-data-dir --disable-ipv6 --disable-sync --disable-translate --kiosk --incognito $WEBSITE  &
				CHROMEPID=$!
			fi
		done
	else
		sleep 1
	fi
done



# # Make sure chrome is running
# while [ 1 ]
# do
# 	for i in {1..10}
# 	do
# 		curl -I ${WEBSITE} >/dev/null 2>&1
# 		RET=$?
# 		if [ $RET -eq 0 ]; then
# 			break
# 		else
# 			echo "No connection to host, try "$i
# 		fi
# 	done
# 	if [ $RET -ne 0 ]
# 	then
# 		echo [`date`] "No connection to host" >> ${LOGFILE}
# 		if [ $CHROMEPID -ne -1 ]
# 		then
# 			kill $CHROMEPID
# 			CHROMEPID=-1
# 		fi
# 	else
# 		kill -0 $CHROMEPID
# 		if [ $? -ne 0  -o $CHROMEPID -eq -1 ]; then
# 			chrome --user-data-dir --disable-ipv6 --disable-sync --disable-translate --kiosk --incognito $WEBSITE  &
# 			CHROMEPID=$!
# 		fi
# 	fi
# 	sleep 2
# done
