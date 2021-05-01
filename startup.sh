#!/bin/sh

log() {
  echo "[l2tp-transmission @$(date +'%F %T')] $1"
}

whereAmI() {
  local var=$(curl -s ipconfig.io/json)
  local ip=$(echo $var|grep -Po '"ip":.*?[^\\]",'|grep -zoP '"ip":\s*\K[^\s,]*(?=\s*,)'|tr '\0' '\n'|tr -d "\"")
  local country=$(echo $var|grep -Po '"country":.*?[^\\]",'|grep -zoP '"country":\s*\K[^\s,]*(?=\s*,)'|tr '\0' '\n'|tr -d "\"")
  local city=$(echo $var|grep -Po '"city":.*?[^\\]",'|grep -zoP '"city":\s*\K[^\s,]*(?=\s*,)'|tr '\0' '\n'|tr -d "\"")
  log "Current IP address is $ip. Location is $country, $city."
}

transmissionSetup() {
  log "Launching Transmission"
  
  TRANSMISSION_DOWNLOAD_DIR="/download"
  TRANSMISSION_INCOMPLETE_DIR="/incomplete"
  TRANSMISSION_WATCH_DIR="/watch"
    
  # Edit Transmission config file
  if [ -n "$USER_T" ] ; then
    sed -i 's/"rpc-username.*/"rpc-username": "'$USER_T'",/' /config/settings.json
  fi
  if [ -n "$PASSWD_T" ]; then
    sed -i 's/"rpc-password.*/"rpc-password": "'$PASSWD_T'",/' /config/settings.json
  fi
  if [ -n "$PORT_T" ]; then
    sed -i 's/"rpc-port.*/"rpc-port": '$PORT_T',/' /config/settings.json
  fi
  
  . /etc/userSetup.sh
  
  # Get rid of some Transmission warnings by settings bigger send/receive buffers
  sed -i '/net.core.rmem_max = .*/d' /etc/sysctl.conf
  sed -i '/net.core.wmem_max = .*/d' /etc/sysctl.conf
  echo "net.core.rmem_max = 4194304" >> /etc/sysctl.conf
  echo "net.core.wmem_max = 1048576" >> /etc/sysctl.conf
  sysctl -p
  log "The last two commands issued an error, this is a known behaviour. See https://github.com/moby/moby/issues/30778"
  # NOTE: This has not effect yet, see https://github.com/moby/moby/issues/30778
  
  # Launch Transmission
  log "Launching transmission with user ${RUN_AS}"
  exec su -p ${RUN_AS} -s /bin/sh -c "/usr/bin/transmission-daemon --foreground --config-dir /config"
}

setTable() {
  log "Updating routing table"
  log "Your routing table was:"
  ip route
  echo ""
  ip addr
  echo ""
  
  # Setup routing table
  local localIp=$(ip addr|grep "eth0"| grep "inet"|awk -F ' ' '{print $2}')
  echo "LocalIP = $localIp"
  local localNet=$(ipcalc -n $localIp|awk -F '=' '{print $2}')
  local mask=$(echo $localIp| awk -F '/' '{print $2}')
  local network=$(echo $localNet"/"$mask)
  local device=$(ip route show to default | grep -Eo "dev\s*[[:alnum:]]+" | sed 's/dev\s//g')
  local gw=$(ip route |awk '/default/ {print $3}')
  local myip=$(ip addr show dev eth0|grep "inet"|awk '{print $2}'|awk -F '/' '{print $1}')

  echo "ip route add $VPN_SERVER_IPV4 via $gw dev $device proto static metric 100"
  ip route add $VPN_SERVER_IPV4 via $gw dev $device proto static metric 100
  
  echo "ip route add "$network" via $gw dev $device proto static metric 70"
  ip route add "$network" via $gw dev $device proto static metric 70
  
  # Set a route back to local network
  if [ -n "$LAN" ]; then
    echo "ip route add $LAN via $gw dev $device proto static metric 70"
    ip route add $LAN via $gw dev $device proto static metric 70
  fi
  
  echo "ip route add default dev ppp0 proto static scope link metric 50"
  ip route add default dev ppp0 proto static scope link metric 50
  
  echo "ip route del default via $gw"
  ip route del default via $gw
  
  echo "ip route del $network dev $device"
  ip route del $network dev $device
  
  sleep 1
  
  log "Routing table updated"
  log "Your routing table is now:"
  ip route
  echo ""
  
  whereAmI
  #sleep 6
}

setupVPN() {
  log "Editing configuration files"
  
  # template out all the config files using env vars
  sed -i 's/right=.*/right='$VPN_SERVER_IPV4'/' /etc/ipsec.conf
  echo ': PSK "'$VPN_PSK'"' > /etc/ipsec.secrets
  sed -i 's/lns = .*/lns = '$VPN_SERVER_IPV4'/' /etc/xl2tpd/xl2tpd.conf
  sed -i 's/name .*/name '$VPN_USERNAME'/' /etc/ppp/options.l2tpd.client
  sed -i 's/password .*/password '$VPN_PASSWORD'/' /etc/ppp/options.l2tpd.client
  
  whereAmI
  
  log "Waiting"
  sleep 3
  
  log "Launching ipsec"
  ipsec up L2TP-PSK
  sleep 3
  ipsec status L2TP-PSK
  
  log "Waiting"
  sleep 2
  
  log "Launching service"
  (sleep 5 && log "Connecting to ppp daemon" && echo "c myVPN" > /var/run/xl2tpd/l2tp-control) &
  
  log "Launching ppp daemon"
  exec /usr/sbin/xl2tpd -p /var/run/xl2tpd.pid -c /etc/xl2tpd/xl2tpd.conf -C /var/run/xl2tpd/l2tp-control -D &
  sleep 10
}


setupVPN

setTable

transmissionSetup

# Useful to debug
tail -f /dev/null

# We never see this
log "Ended"
