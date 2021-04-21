# Test: [OK]
make_backup () {
    ssh -T root@${HOST} <<-SCRIPT
        tar zcvf BACKUP-${NAME}.tar.gz ${FILE[*]}
SCRIPT
}