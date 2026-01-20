#!/bin/sh
set -e

# =============================
# TIMEZONE
# =============================
TZ_VALUE=$(jq -r '.timezone' /data/options.json)

if [ -z "$TZ_VALUE" ] || [ "$TZ_VALUE" = "null" ]; then
  TZ_VALUE="UTC"
fi

export TZ="$TZ_VALUE"

# Aplica timezone no sistema (importante pro strftime)
if [ -f "/usr/share/zoneinfo/$TZ_VALUE" ]; then
  ln -sf "/usr/share/zoneinfo/$TZ_VALUE" /etc/localtime
  echo "$TZ_VALUE" > /etc/timezone
else
  echo "⚠️ Timezone inválido: $TZ_VALUE (usando UTC)"
  export TZ="UTC"
  ln -sf "/usr/share/zoneinfo/UTC" /etc/localtime
  echo "UTC" > /etc/timezone
fi

echo "🕒 Timezone ativo: $TZ"

# =============================
# OPTIONS
# =============================
RTSP_URL=$(jq -r '.rtsp_url' /data/options.json)
SEGMENT_TIME=$(jq -r '.segment_time' /data/options.json)
RETENTION_DAYS=$(jq -r '.retention_days' /data/options.json)

MEDIA_DIR="/media/cameras/a31"

mkdir -p "$MEDIA_DIR"

# =============================
# RETENÇÃO (SAFE MODE)
# =============================
echo "🧹 Retenção configurada: ${RETENTION_DAYS} dias"
echo "📁 Pasta: $MEDIA_DIR"

if [ -z "$RETENTION_DAYS" ] || [ "$RETENTION_DAYS" = "null" ]; then
  echo "⚠️ retention_days inválido/nulo, retenção desativada."
elif [ "$RETENTION_DAYS" -le 0 ]; then
  echo "⚠️ retention_days <= 0, retenção desativada."
else
  echo "📌 Arquivos que serão removidos (mais de ${RETENTION_DAYS} dias):"
  find "$MEDIA_DIR" -type f -name "*.mp4" -mtime +"$RETENTION_DAYS" -print || true

  echo "🗑️ Removendo arquivos antigos..."
  find "$MEDIA_DIR" -type f -name "*.mp4" -mtime +"$RETENTION_DAYS" -delete || true
fi

# =============================
# START
# =============================
echo "🎥 Iniciando gravação RTSP..."
echo "RTSP: $RTSP_URL"
echo "Segmentos: ${SEGMENT_TIME}s"
echo "Saída: $MEDIA_DIR/a31_%Y%m%d_%H%M%S.mp4"

exec ffmpeg -rtsp_transport tcp \
  -use_wallclock_as_timestamps 1 \
  -fflags +genpts+igndts \
  -i "$RTSP_URL" \
  -c:v copy \
  -c:a aac -b:a 64k \
  -f segment \
  -segment_time "$SEGMENT_TIME" \
  -reset_timestamps 1 \
  -strftime 1 \
  "$MEDIA_DIR/a31_%Y%m%d_%H%M%S.mp4"
