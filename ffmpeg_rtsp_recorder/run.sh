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
# RETENÇÃO (executa em loop, em background)
# =============================
run_retention() {
  while true; do
    echo "🧹 [retenção] Verificando arquivos antigos (limite: ${RETENTION_DAYS} dias)..."
    if [ -z "$RETENTION_DAYS" ] || [ "$RETENTION_DAYS" = "null" ]; then
      echo "⚠️ [retenção] retention_days inválido/nulo, retenção desativada."
    elif [ "$RETENTION_DAYS" -le 0 ]; then
      echo "⚠️ [retenção] retention_days <= 0, retenção desativada."
    else
      COUNT=$(find "$MEDIA_DIR" -type f -name "*.mp4" -mtime +"$RETENTION_DAYS" | wc -l)
      if [ "$COUNT" -gt 0 ]; then
        echo "🗑️ [retenção] Removendo $COUNT arquivo(s) com mais de ${RETENTION_DAYS} dias..."
        find "$MEDIA_DIR" -type f -name "*.mp4" -mtime +"$RETENTION_DAYS" -delete || true
      else
        echo "✅ [retenção] Nenhum arquivo antigo para remover."
      fi
    fi
    # Roda de hora em hora. Ajuste se quiser mais ou menos frequente.
    sleep 3600
  done
}

run_retention &
RETENTION_PID=$!
echo "🧹 Processo de retenção iniciado em background (PID $RETENTION_PID)"

# =============================
# START - GRAVAÇÃO RTSP
# =============================
echo "🎥 Iniciando gravação RTSP..."
echo "RTSP: $RTSP_URL"
echo "Segmentos: ${SEGMENT_TIME}s"
echo "Saída: $MEDIA_DIR/a31_%Y%m%d_%H%M%S.mp4"

while true; do
  echo "🚀 Subindo ffmpeg..."
  ffmpeg -rtsp_transport tcp \
    -rtsp_flags prefer_tcp \
    -timeout 15000000 \
    -rw_timeout 15000000 \
    -use_wallclock_as_timestamps 1 \
    -fflags +genpts+igndts \
    -i "$RTSP_URL" \
    -c:v copy \
    -af aresample=async=1:first_pts=0 \
    -c:a aac -b:a 48k \
    -f segment \
    -segment_time "$SEGMENT_TIME" \
    -reset_timestamps 1 \
    -strftime 1 \
    "$MEDIA_DIR/a31_%Y%m%d_%H%M%S.mp4"

  echo "⚠️ ffmpeg caiu ou travou. Tentando novamente em 5s..."
  sleep 5
done
