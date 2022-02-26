# wireless-hdmi-bridge
> See, [TC358743 CSI-2 Converter Chipset (HDMI to MIPI)](https://toshiba.semicon-storage.com/content/dam/toshiba-ss/ncsa/en_us/docs/product-brief/assp/10L02_TC358743_ProdBrief.pdf) interface [configuration](https://forums.raspberrypi.com/viewtopic.php?t=281972)

## ToC
* [macOS](#macos)
* [Footnotes](#footnotes)

## macOS
> between a Raspberry Pi 2 sender and macOS receiver, using [HDMI to CSI Adapter](https://www.waveshare.com/hdmi-to-csi-adapter.htm)

* assemble hardware and connect non HDCP HDMI source[[fn1](#footnotes)]
* create a fleet in balenaCloud, push release and add device
* configure `dtoverlay=tc358743`
* set configuration variable `BALENA_HOST_CONFIG_gpu_mem=196`
* set configuration variable `BALENA_HOST_CONFIG_start_x=1`
* set environment variable `IPS={{host}}:{{port}}` to the IP of the macOS receiver
* install GStreamer tools on the receiver workstation

```sh
brew install \
  gstreamer \
  gst-plugins-base \
  gst-plugins-good
```

* ensure UDP `{{port}}` isn't blocked by firewall(s) on the network
* start receiver

```sh
gst-launch-1.0 -vvv \
  udpsrc port={{port}} \
  ! 'application/x-rtp,media=(string)video,clock-rate=(int)90000,encoding-name=(string)H264,payload=(int)96' \
  ! rtpjitterbuffer \
  ! rtph264depay \
  ! avdec_h264 \
  ! videoconvert \
  ! glimagesink
```

## Footnotes

* This solution does not support devices, which attempt to negotiate a secure/encrypted
  HDCP HDMI connection. This includes most STBs (e.g. Amazon FireTV Cube, Apple TV, etc.).
  Use a HDCP HDMI stripper switch if working with such devices.

* While there is a `tc358743-audio` overlay, I2S audio is unlikely to work on [cheap clone boards](https://forums.raspberrypi.com/viewtopic.php?t=279108).
  If you require HDMI audio, ensure you have [appropriate hardware](https://auvidea.eu/product/b102-hdmi-to-csi-2-bridge-rev-2-with-i2s-audio/).
