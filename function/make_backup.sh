# Test: [OK]
make_backup () {
    ssh -T root@127.0.0.1 <<-SCRIPT
        tar zcvf BACKUP-${NAME}.tar.gz\
       ${DIR_BACKUP}/${FILE}
SCRIPT
}