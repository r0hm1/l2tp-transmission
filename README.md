l2tp-transmission
===
[![License](https://img.shields.io/github/license/mashape/apistatus.svg)](https://github.com/r0hm1/l2tp-transmission/blob/master/LICENSE)

A tiny Alpine 3.11 based docker image to quickly setup Transmission and an L2TP over IPsec VPN client w/ PSK.

## Motivation
So you wanted to run [this](https://hub.docker.com/r/haugene/transmission-openvpn) container but your VPN provider does not provide OpenVPN compliance.
All you need:

1. VPN Server Address
2. Pre Shared Key
3. Username
4. Password

## Quick start

### Docker run
```
    $ docker run --rm -it --privileged \
           --name l2tp-transmission\
           -v /lib/modules:/lib/modules:ro \
           -v /home/user/torrent/download:/download \
           -v /home/user/torrent/incomplete:/incomplete \
           -v /home/user/torrent/watch:/watch \
           -e VPN_SERVER_IPV4=000.000.000.000 \
           -e VPN_PSK= \
           -e VPN_USERNAME= \
           -e VPN_PASSWORD= \
           -e TZ=Europe/Paris \
           -e PUID=1002 \
           -e PGID=100 \
           -e USER_T=transmission \
           -e PASSWD_T=password \
           -e PORT_T=9091 \
           -e LAN=192.168.1.0/24 \
           -p 9091:9091/tcp\
           --net=vpn-network \
           r0hm1/l2tp-transmission
```
### Docker compose
```
version: '3'

volumes:
  transmission-vpn_config:
    name: transmission-vpn_config

networks:
  vpn-network:
    external: true
    name: vpn-network

services:
  l2tp-transmission:
    image: r0hm1/l2tp-transmission:latest
    container_name: l2tp-transmission
    hostname: l2tp-transmission
    privileged: true
    cap_add:
      - NET_ADMIN
    networks:
      - vpn-network
    ports:
      - 9091:9091 # transmission
      - 9117:9117 # optional, jackett
      - 7878:7878 # optional, radarr
      - 8686:8686 # optional, lidarr
    volumes:
      - /lib/modules:/lib/modules:ro
      - transmission-vpn_config:/config:rw
      - /home/user/torrent/download:/download:rw
      - /home/user/torrent/incomplete:/incomplete:rw
      - /home/user/torrent/watch:/watch:rw
    environment:
      - VPN_SERVER_IPV4=000.000.000.000
      - VPN_PSK=
      - VPN_USERNAME=
      - VPN_PASSWORD=
      - TZ=Europe/Paris
      - PUID=1002
      - PGID=100
      - LAN=192.168.1.0/24
      - USER_T=transmission
      - PASSWD_T=password
      - PORT_T=9091
    restart: unless-stopped
```

## Configuration options

### Volumes
You can use a `volume` mapped to `/config` to store the Transmission configuration files.

### Network
The Compose file above uses a separate bridge network `vpn-network`. You can also use the default `bridge` network. **Dont' use the `host` network as this container will mess with your routing table.**

Tell `l2tp-transmission` what network you will be using to access the web interface:
```
environment:
      ...
      - LAN=192.168.1.0/24
      ...
```
and expose the port that is needed:
```
ports:
      ...
      - 9091:9091 # transmission
      ...
```

### Environment

| Variable          | Use            | Optional?  |
| ----------------- |:-------------- | :-----|
| `VPN_SERVER_IPV4` | The IP address (not the server name) of the VPN server you want to connect to. Given by your VPN supplier. | Mandatory |
| `VPN_PSK`         | The Pre Shared Key. Given by your VPN supplier. | Mandatory |
| `VPN_USERNAME`    | The username you used to sign up to your VPN supplier. | Mandatory |
| `VPN_PASSWORD`    | The password you used to sign up to your VPN supplier. | Mandatory |
| `TZ`              | The timezone you are in. Used for the logs.  | Optional |
| `PUID`            | The UID Transmission will run with. You might run into permission issues if you do not set it. | Optional |
| `PGID`            | Same as `PUID` but for group. | Optional |
| `LAN`             | The network from which you will be accessing the web interface. | Mandatory |
| `USER_T`          | The username to access Transmission web interface. Default is transmission. | Optional |
| `PASSWD_T`        | The password to access Transmission web interface. Default is password. | Optional |
| `PORT_T`          | The port to access Transmission web interface. Default is 9091. | Optional |

### Advanced networking

This container can provide VPN'ed internet traffic to other containers as well, using the `network_mode: container` option. Here is an example with jackett:

```
version: '3'

volumes:
  jackett_config:
    name: jackett_config

services:
  jackett:
    image: ghcr.io/linuxserver/jackett:amd64-latest
    container_name: jackett
    network_mode: container:l2tp-transmission
    environment:
      - PUID=1002
      - PGID=100
      - TZ=Europe/Paris
      - AUTO_UPDATE=true #optional
    volumes:
      - jackett_config:/config
      - /home/user/torrent/watch:/downloads
    restart: unless-stopped
```

In order to be  able to access jackett web interface, you will need to expose the corresponding port in `l2tp-transmission` configuration:
```
ports:
      ...
      - 9117:9117 # optional, jackett
      ...
```

## References
* [https://hub.docker.com/r/ubergarm/l2tp-ipsec-vpn-client/](https://hub.docker.com/r/ubergarm/l2tp-ipsec-vpn-client/)
* [https://hub.docker.com/r/haugene/transmission-openvpn/](https://hub.docker.com/r/haugene/transmission-openvpn/)
