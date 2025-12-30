#!/bin/sh

RTSP_URL=$(jq -r '.rtsp_url' /data/options.json)
SEGMENT_TIME=$(jq -r '.segment_time' /data/options.json)
RETENTION_DAYS=$(jq -r '.retention_days' /data/options.json)

MEDIA_DIR="/media/cameras/a31"

mkdir -p "$MEDIA_DIR"

echo "🧹 Limpando arquivos com mais de ${RETENTION_DAYS} dias..."
find "$MEDIA_DIR" -type f -name "*.mp4" -mtime +"$RETENTION_DAYS" -delete

echo "🎥 Iniciando gravação RTSP..."
echo "RTSP: $RTSP_URL"
echo "Segmentos: ${SEGMENT_TIME}s"

exec ffmpeg -rtsp_transport tcp \
  -use_wallclock_as_timestamps 1 \
  -fflags +genpts \
  -i "$RTSP_URL" \
  -c:v copy \
  -c:a aac -b:a 64k \
  -f segment \
  -segment_time "$SEGMENT_TIME" \
  -reset_timestamps 1 \
  -strftime 1 \
  "$MEDIA_DIR/a31_%Y%m%d_%H%M%S.mp4"
