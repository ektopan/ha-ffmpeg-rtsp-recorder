#!/bin/sh

RTSP_URL=$(jq -r '.rtsp_url' /data/options.json)
SEGMENT_TIME=$(jq -r '.segment_time' /data/options.json)

mkdir -p /media/cameras/a31

echo "Iniciando gravação RTSP..."
echo "RTSP: $RTSP_URL"
echo "Segmentos: ${SEGMENT_TIME}s"

ffmpeg -rtsp_transport tcp \
  -i "$RTSP_URL" \
  -an \
  -c copy \
  -f segment \
  -segment_time "$SEGMENT_TIME" \
  -reset_timestamps 1 \
  -strftime 1 \
  /media/cameras/a31/a31_%Y%m%d_%H%M%S.mp4


