# subshell: [true]
make_backup () {
    NAME="$1" && shift
    FILE="$@" 
    tar zcvf ${NAME}.tar.gz ${FILE}
}
make_backup $@