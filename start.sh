#!/bin/bash
VIDEODEV=/dev/video0

echo "Balena HDMI Link startup..."
if [ -c "$VIDEODEV" ]; then
    echo "I see a video input, looks like I am the master"
    
    # Find the IPs of the other devices in the app
    IPS=$(curl -X GET "https://api.balena-cloud.com/v5/application($BALENA_APP_ID)?\$expand=owns__device" \
    -H "Content-Type: application/json" \
    -H "Authorization: Bearer $balenacloud_api_key" | \
    jq "[ .d | .[0] | .[\"owns__device\"] | .[] | select(.uuid != \""$BALENA_DEVICE_UUID"\") | \"[f=mpegts]udp://\" + .ip_address + \":8888\" ] | join(\"|\")")
    
    echo "Targets: $IPS"
    
    v4l2-ctl --set-fmt-video=width=1280,height=720
    v4l2-ctl -d /dev/video0 -p 25
    
    # IPS isn't being passed by exec correctly
    exec ffmpeg -re -fflags nobuffer -f v4l2 -input_format h264 -i /dev/video0 -c copy -f tee -map 0 $IPS
else 
    echo "I don't see any input, I must be an output device"
    exec omxplayer -g --live udp://0.0.0.0:8888?listen --aspect-mode stretch
fi