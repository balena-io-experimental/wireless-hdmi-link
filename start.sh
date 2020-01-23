#!/bin/bash
VIDEODEV=/dev/video0

echo "Balena HDMI Link startup..."

if [ -c "$VIDEODEV" ]; then
    echo "I see a video input, looks like I am the master"
    
    # Load the HDMI capture board with the valid modes (via EDID)
    v4l2-ctl --set-edid=file=1080P50EDID.txt --fix-edid-checksums
        
    # Find the IPs of the other devices in the app, so we know where to send the output
    IPS=$(curl -sX GET "https://api.balena-cloud.com/v5/application($BALENA_APP_ID)?\$expand=owns__device" \
    -H "Content-Type: application/json" \
    -H "Authorization: Bearer $balenacloud_api_key" | \
    jq "[ .d | .[0] | .[\"owns__device\"] | .[] | select(.uuid != \""$BALENA_DEVICE_UUID"\") | \"\" + .ip_address + \":8888\" ] | join(\",\")")
    
    echo "Targets: $IPS"
    
    # Set the device timings to those detected on the link
    v4l2-ctl --set-dv-bt-timings query
    
    exec gst-launch-1.0 -v \
      v4l2src \
      ! "video/x-raw,framerate=60/1,format=UYVY" \
      ! videorate max-rate=25 \
      ! v4l2h264enc \
      ! h264parse \
      ! mpegtsmux \
      ! rtpmp2tpay \
      ! multiudpsink clients=10.19.0.229:8888,$IPS

else 
    echo "I don't see any input, I must be an output device"
    while : ; do echo "${MESSAGE=Idling...}"; sleep ${INTERVAL=600}; done
    # exec omxplayer -g --live udp://0.0.0.0:8888?listen --aspect-mode stretch
fi