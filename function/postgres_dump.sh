# Test: [OK]
postgresql_dump () {

    /usr/bin/pg_dump -U ${USER_POSTGRESQL} "$1" | \
    ${COMPRESS_ALG} -c > ${DIR_BACKUP}/${BASE,,}/${BASE,,}-${DATE_TODAY}.sql.bz2

}