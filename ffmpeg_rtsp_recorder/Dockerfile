FROM ghcr.io/home-assistant/base:latest

RUN apk add --no-cache ffmpeg

COPY run.sh /run.sh
RUN chmod +x /run.sh

CMD ["/run.sh"]
