#!/bin/sh

# More/less taken from https://github.com/haugene/docker-transmission-openvpn/blob/master/transmission/userSetup.sh

RUN_AS=root
GLOBAL_APPLY_PERMISSIONS=true

if [ -n "$PUID" ] && [ ! "$(id -u root)" -eq "$PUID" ]; then
    RUN_AS=abc
    
    res=$(id -g ${RUN_AS})
    
    if [ -n "$PGID" ] && ( [ ! -n "$res" ] || [ ! "$res" -eq "$PGID" ]); then
        #groupmod -o -g "$PGID" ${RUN_AS};
        addgroup ${RUN_AS} --gid $PGID;
    fi
    
    res=$(id -u ${RUN_AS})
    if ( [ ! -n "$res" ] || [ ! "$res" -eq "$PUID" ] ); then
        #usermod -o -u "$PUID" ${RUN_AS};
        adduser ${RUN_AS} --disabled-password --uid $PUID --ingroup ${RUN_AS} --shell /bin/sh
    fi

    if [[ "true" = "$LOG_TO_STDOUT" ]]; then
      chown ${RUN_AS}:${RUN_AS} /dev/stdout
    fi

    # Make sure directories exist before chown and chmod
    mkdir -p /config \
        ${TRANSMISSION_DOWNLOAD_DIR} \
        ${TRANSMISSION_INCOMPLETE_DIR} \
        ${TRANSMISSION_WATCH_DIR}

    log "Enforcing ownership on transmission config directories"
    chown -R ${RUN_AS}:${RUN_AS} \
        /config

    log "Applying permissions to transmission config directories"
    chmod -R go=rX,u=rwX \
        /config

    if [ "$GLOBAL_APPLY_PERMISSIONS" = true ] ; then
        log "Setting owner for transmission paths to ${PUID}:${PGID}"
        chown -R ${RUN_AS}:${RUN_AS} \
            ${TRANSMISSION_DOWNLOAD_DIR} \
            ${TRANSMISSION_INCOMPLETE_DIR} \
            ${TRANSMISSION_WATCH_DIR}

        log "Setting permission for files (644) and directories (755)"
        chmod -R go=rX,u=rwX \
            ${TRANSMISSION_DOWNLOAD_DIR} \
            ${TRANSMISSION_INCOMPLETE_DIR} \

        log "Setting permission for watch directory (775) and its files (664)"
        chmod -R o=rX,ug=rwX \
            ${TRANSMISSION_WATCH_DIR}
    fi
fi

log "
-------------------------------------
Transmission will run as
-------------------------------------
User name:   ${RUN_AS}
User uid:    $(id -u ${RUN_AS})
User gid:    $(id -g ${RUN_AS})
-------------------------------------
"

export PUID
export PGID
export RUN_AS
