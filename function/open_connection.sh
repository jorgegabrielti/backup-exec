# Test: [OK]
open_connection () {
    pssh --hosts=${PSSH_HOSTS} --send-input \
        'bash -s' < ${WORK_DIR}/function/make_backup.sh  ${NAME} ${FILE[*]}
}