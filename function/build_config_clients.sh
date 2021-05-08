# Test: [OK]
build_config_clients () {
    
    # Global config
    GLOBAL_CONFIG="conf/include/global-config"
    grep -Ev '^$|^#' conf/backup.conf | grep -vi include > ${GLOBAL_CONFIG}

    # Build pssh file hosts
    PSSH_HOSTS="./.pssh_hosts"

    if [ ! -e ${PSSH_HOSTS} ]; then
        for FILE in ${WORK_DIR}/conf/include/*.conf; do
            CLIENT=$(grep -E '^USER=|^HOST=' ${FILE} \
            | cut -d'=' -f2 \
            | sort -r | paste -s \
            | tr -s '[:blank:]' '@') 
            echo ${CLIENT}>> ${PSSH_HOSTS}
        done
    else 
        rm -f ${PSSH_HOSTS}
        for FILE in ${WORK_DIR}/conf/include/*.conf; do
            CLIENT=$(grep -E '^USER=|^HOST=' ${FILE} \
            | cut -d'=' -f2 \
            | sort -r | paste -s \
            | tr -s '[:blank:]' '@') 
            echo ${CLIENT}>> ${PSSH_HOSTS}
        done
    fi
    
    # Build pssh file hosts
    for FILE in ${WORK_DIR}/conf/include/*.conf; do
        CLIENT=$(grep -E '^USER=|^HOST=' ${FILE} \
        | cut -d'=' -f2 \
        | sort -r | paste -s \
        | tr -s '[:blank:]' '@')
        parse ${FILE}
        scp backup-agent.sh ${GLOBAL_CONFIG} ${FILE}.db backup_job_discovery.sh ${CLIENT}:/tmp/
        rm -f ${FILE}.db 
    done
    rm -f ${GLOBAL_CONFIG}
}