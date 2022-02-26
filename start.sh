#!/usr/bin/env bash

set -ae

VIDEODEV=${VIDEODEV:-/dev/video0}
EDID_FILE=${EDID_FILE:-1080P60EDID.txt}
PIXEL_FORMAT=${PIXEL_FORMAT:-UYVY}

function finish {
  # crash loop backoff
  sleep 10s
}
trap finish EXIT

[[ $VERBOSE =~ true|True|On|on|Yes|yes|1 ]] && set -x

echo "Balena HDMI Link startup..."

v4l2-ctl --list-devices

if [ -c "$VIDEODEV" ]; then
    echo "I see a video input, looks like I am the master"

    # Load the HDMI capture board with the valid modes (via EDID)
    v4l2-ctl --set-edid=file="${EDID_FILE}" --fix-edid-checksums

    # Find the IPs of the other devices in the app, so we know where to send the output
    ips="$(curl -s "${BALENA_API_URL}/v6/application(${BALENA_APP_ID})?\$expand=owns__device" \
      -H "Content-Type: application/json" \
      -H "Authorization: Bearer ${BALENA_API_KEY}" \
      | jq --arg uuid "${BALENA_DEVICE_UUID}" \
      '[ .d | .[0] | .["owns__device"] | .[] | select(.uuid != $uuid) | "" + .ip_address + ":8888" ] | join(",")')"

    IPS=${IPS:-$ips}

    echo "Targets: ${IPS}"
    
    # Print the currently detected timings
    v4l2-ctl --query-dv-timings

    # Set the device timings to those detected on the link
    v4l2-ctl --set-dv-bt-timings query

    v4l2-ctl -v pixelformat="${PIXEL_FORMAT}"

    v4l2-ctl -V

    [[ $VERBOSE =~ true|True|On|on|Yes|yes|1 ]] && v4l2-ctl --log-status

    pipeline=${GST_INPUT_PIPELINE:-v4l2src \
      ! 'video/x-raw,framerate=60/1,format=UYVY' \
      ! v4l2h264enc \
      ! video/x-h264,profile=high,level=(string)4 \
      ! h264parse \
      ! rtph264pay \
      ! multiudpsink clients=$IPS}

    exec gst-launch-1.0 -vvv ${pipeline}

else
    echo "I don't see any input, I must be an output device"

    pipeline=${GST_OUTPUT_PIPELINE:-udpsrc \
      port=8888 \
      ! 'application/x-rtp,media=(string)video,clock-rate=(int)90000,encoding-name=(string)H264,payload=(int)96' \
      ! rtph264depay \
      ! decodebin \
      ! videoconvert \
      ! autovideosink}

    exec gst-launch-1.0 -vvv ${pipeline}
fi
