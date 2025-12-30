FROM alpine:3.19

RUN apk add --no-cache ffmpeg jq tzdata

COPY run.sh /run.sh
CMD ["sh", "/run.sh"]
