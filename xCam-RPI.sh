#!/bin/bash
version="1.0"

### CONFIGURATION
max_x=4095 # This will be used if script won't detect maximum ABS_X
max_y=4095 # This will be used if script won't detect maximum ABS_Y

resolution_x=800
resolution_y=480

### END OF CONFIGURATION

if [[ $EUID -ne 0 ]]; then
   echo "ERROR: xCam-RPI works only under root"
   exit 0
fi

clear
echo "=> xCam-RPI ${version} <="
echo

### TRYING TO AUTODETECT MAX_X MAX_Y SETTINGS FOR ABS
autodetected_screen=$(cat /proc/bus/input/devices | awk '/screen/{for(a=0;a>=0;a++){getline;{if(/mouse/==1){ print $NF;exit 0;}}}}'|cut -d " " -f 3)
detected_max_x=$(evtest /dev/input/${autodetected_screen}|grep Max|awk {'print $2'}|tr "\n" ","|cut -d ',' -f 1& sleep 1; killall -9 evtest)
detected_max_y=$(evtest /dev/input/${autodetected_screen}|grep Max|awk {'print $2'}|tr "\n" ","|cut -d ',' -f 2& sleep 1; killall -9 evtest)

if [[ ${detected_max_y} != 0 && ${detected_max_x} != 0 ]]; then
        echo "-> Maximum ABS values detected automatically"
        max_x=${detected_max_x}
        max_y=${detected_max_y}
else
        echo "-> Could not autodetect max ABS values, using values from config"
fi

### PREPARING VIEW SETTINGS BASED ON JSON CONFIG
echo "-> Preparing views..."

cameras=$(jq '. | length' cameras.json)
cameras_x=$(echo "sqrt(${cameras})" | bc)

        if [[ $(echo "${cameras} % ${cameras_x}" | bc) == 0 ]]; then
                cameras_y=${cameras_x}
        else
                cameras_y=$((${cameras_x}+1))
        fi

camera_width=$((${resolution_x} / ${cameras_x}))
camera_height=$((${resolution_y} / ${cameras_y}))

function checkCommand(){
        command=${1}
        echo "-> Checking if ${command} is available"
        if ! $(command -v ${command} &> /dev/null); then
                echo "-> MISSING PACKAGE: ${command} package needs to be installed"
                exit 1
        fi
}

function runStream(){
        xs=0
        xe=${camera_width}
        ys=0
        ye=${camera_height}

        echo "-> Starting streams..."

        rm /tmp/xCam-RPI.cameras || echo "-> No old data for cameras to be removed."
        touch /tmp/xCam-RPI.cameras || echo "-> Can't create /tmp/xCam-RPI.cameras. Make sure you have sufficent priviledges"

        current_cam=0
        cam_count=0

        jq -c '.[]' cameras.json | while read i; do
                stream=$(echo ${i} | jq -r '.stream')
                name=$(echo ${i} | jq -r '.name')

                if [[ ${current_cam} == ${cameras_x} ]]; then
                        ys=$((${ys} + ${camera_height}))
                        ye=$((${ys} + ${camera_height}))
                        xs=0
                        current_cam=0
                fi

                echo "${xs} ${ys} ${xe} ${ye}" >> /tmp/xCam-RPI.cameras
                omxplayer --no-keys --no-osd --avdict rtsp_transport:tcp --win "${xs} ${ys} ${xe} ${ye}" ${stream} --live -n -1 --timeout 30 --dbus_name org.mpris.MediaPlayer2.omxplayer.${name} > /dev/null 2>&1 &
                xs=$((${xs} + ${camera_width}))
                xe=$((${xe} + ${camera_width}))

                if [[ $((${resolution_x} - ${xe})) -lt 0 ]]; then
                        xs=0
                        xe=${camera_width}
                fi

                current_cam=$((${current_cam}+1))
                cam_count=$((${cam_count}+1))
        done
        echo "-> All ready, have fun!"
}

function runStreamFullScreen(){
        x=${1}
        y=${2}
        cam_count=1
        jq -c '.[]' cameras.json | while read i; do
                stream=$(echo ${i} | jq -r '.stream')
                name=$(echo ${i} | jq -r '.name')
                x_s=$(cat /tmp/xCam-RPI.cameras | head -n ${cam_count}|tail -n1|cut -d " " -f 1)
                y_s=$(cat /tmp/xCam-RPI.cameras | head -n ${cam_count}|tail -n1|cut -d " " -f 2)
                x_e=$(cat /tmp/xCam-RPI.cameras | head -n ${cam_count}|tail -n1|cut -d " " -f 3)
                y_e=$(cat /tmp/xCam-RPI.cameras | head -n ${cam_count}|tail -n1|cut -d " " -f 4)

                if [[ ${x} > ${x_s} && ${x} < ${x_e} && ${y} > ${y_s} && ${y} < ${y_e} ]]; then
                        omxplayer --layer 101 --no-keys --no-osd --avdict rtsp_transport:tcp --win "0 0 ${resolution_x} ${resolution_y}" ${stream} --live -n -1 --timeout 30 --dbus_name org.mpris.MediaPlayer2.omxplayer.${name} > /dev/null 2>&1 &
                        touch /tmp/xCam-RPI.video_running
                fi
                cam_count=$((${cam_count}+1))
        done
}

checkCommand jq
checkCommand omxplayer
checkCommand evtest
runStream

if [[ ${1} != '--notouch' ]]; then
        while true; do
                timeout 0.3s evtest /dev/input/event4 > /tmp/xCam-RPI.touch_test
                grep "SYN_REPORT" /tmp/xCam-RPI.touch_test

                if [[ $? == 0 ]]; then

                        if [[ -f /tmp/xCam-RPI.video_running ]]; then
                                kill -9 $(ps aux|grep omxplayer|grep layer|grep 101|awk {'print $2'})
                                rm /tmp/xCam-RPI.video_running || "No video running at the moment"
                        else
                                touched_x=$(grep -m 3 'type 3' /tmp/xCam-RPI.touch_test|grep ABS_X |awk {'print $11'})
                                touched_y=$(grep -m 3 'type 3' /tmp/xCam-RPI.touch_test|grep ABS_Y |awk {'print $11'})
                                x=$( bc -l <<< ${touched_x}/${max_x}*${resolution_x}|cut -d '.' -f 1 )
                                y=$( bc -l <<< ${touched_y}/${max_y}*${resolution_y}|cut -d '.' -f 1 )
                                runStreamFullScreen ${x} ${y}
                        fi
                fi
        done
else
        echo "-> Running without touch screen, zooming won't be possible."
        ( trap exit SIGINT ; read -r -d '' _ </dev/tty )
fi
