# Test: [OK]
open_connection () {
    ssh root@${HOST} \
        'bash -s' < ${WORK_DIR}/function/make_backup.sh  ${NAME} ${FILE[*]}
}