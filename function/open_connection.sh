# Test: [OK]
open_connection () {
    pssh --host=${HOST} --user=root --send-input \
        'bash -s' < ${WORK_DIR}/function/make_backup.sh  ${NAME} ${FILE[*]}
}