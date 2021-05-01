FROM alpine:3.11

# Set correct default environment variables.
ENV USER_T transmission
ENV PASSWD_T password
ENV PORT_T 9091
ENV LANG C.UTF-8
ENV TZ Europe/Paris
ENV PUID 1002
ENV PGID 100

# Copy config files for transmission
COPY settings.json /tmp/settings.json

RUN set -x && \
    apk add --no-cache  \
              strongswan \
              xl2tpd \
              curl \
              grep \
              tzdata \
              transmission-daemon=2.94-r3 \
              transmission-cli=2.94-r3 \
              nano \
    && mkdir -p /var/run/xl2tpd \
    && touch /var/run/xl2tpd/l2tp-control \
    && mkdir -p /config \
    && mkdir -p /transmission/finished \
    && mkdir -p /transmission/incomplete \
    && mkdir -p /transmission/watch \
    && chmod -R 777 /transmission \
    && false | cp -i /tmp/settings.json /config/settings.json 2>/dev/null \
    && rm -rf /tmp/*

# Copy config files for l2tp
COPY ipsec.conf /etc/ipsec.conf
COPY ipsec.secrets /etc/ipsec.secrets
COPY xl2tpd.conf /etc/xl2tpd/xl2tpd.conf
COPY options.l2tpd.client /etc/ppp/options.l2tpd.client

# Copy scripts
COPY startup.sh /etc/
COPY userSetup.sh /etc/

VOLUME /config

EXPOSE 9091

WORKDIR /home

CMD ["/etc/startup.sh"]
