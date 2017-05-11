FROM alpine:3.5

RUN apk add --no-cache py-pip curl jq \
    && pip install docker-compose

ADD auto-compose.sh /usr/local/sbin/auto-compose.sh

ENTRYPOINT ["/usr/local/sbin/auto-compose.sh"]
