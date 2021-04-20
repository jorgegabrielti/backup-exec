# Test: [OK]
recicly () {
for DIR in $(cat base_listdir.txt); do
    find ${DIR} -maxdepth 1 -type f -iname "*.bz2" -mtime +5 -exec rm -f {} \;
    find ${DIR}/logs/ -maxdepth 1 -type f -iname "*.bz2.log" -mtime +5 -exec rm -f {} \;
done
}