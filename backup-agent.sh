DATE_TODAY=$(date +%d-%m-%Y)

# Test: [OK]
trapper () {
  /usr/bin/zabbix_sender -z "$1" -p "$2" -s "$3" -k "$4" -o "$5"
}

# Test: [OK]
recicly () {
  for DIR in $(cat base_listdir.txt); do
      find ${DIR} -maxdepth 1 -type f -iname "*.bz2" -mtime +5 -exec rm -f {} \;
      find ${DIR}/logs/ -maxdepth 1 -type f -iname "*.bz2.log" -mtime +5 -exec rm -f {} \;
  done
}

# Test: [OK]
postgresql_dump () {

    /usr/bin/pg_dump -U ${USER_POSTGRESQL} ${DATABASE} | \
    ${COMPRESS_ALG} -c > ${STORAGE}/${BASE,,}/${BASE,,}-${DATE_TODAY}.sql.bz2

}

# Test: [OK]
hash_checksum () {

  ${CHECKSUM_TYPE}sum "$1" > "$1".${CHECKSUM_TYPE}

}

# Test: [OK]
aws_s3sync () {
  time for BACKUP in ${@}; do
           time /usr/local/bin/aws s3 cp ${BACKUP} s3://${BUCKET}/
       done
}

# Test: [OK]
aws_assume_role () {
   # Unset environment variables
   unset AWS_ACCESS_KEY_ID AWS_SECRET_ACCESS_KEY AWS_SESSION_TOKEN

   # User assume role
   /usr/local/bin/aws sts assume-role --role-arn ${ARN_ROLE} --role-session-name appsMakerAssumeRole > /tmp/.assumeRole.tmp

   # Get secrets
   export AWS_ACCESS_KEY_ID=$(grep -E 'AccessKeyId' /tmp/.assumeRole.tmp | awk '{print $2}' | tr -d '"|,')
   export AWS_SECRET_ACCESS_KEY=$(grep -E 'SecretAccessKey' /tmp/.assumeRole.tmp | awk '{print $2}' | tr -d '"|,')
   export AWS_SESSION_TOKEN=$(grep -E 'SessionToken' /tmp/.assumeRole.tmp | awk '{print $2}' | tr -d '"|,')
}

### Build a regular file
regular_file_backup ()
{
  # Storage directory
  if [ ! -d ${STORAGE} ]; then
       mkdir ${STORAGE}
  fi 
    
  tar zcvf ${STORAGE}/${NAME}.tar.gz ${FILE[*]}
     
  ### Call functions 
  # Checksum
  hash_checksum ${STORAGE}/${NAME}.tar.gz   
  
  # AWS Assume Role
  #aws_assume_role

  # AWS S3 Sync
  #aws_s3sync /${STORAGE}/${NAME}.tar.gz ${STORAGE}/${NAME}.tar.gz.${CHECKSUM_TYPE}
}

### Build MySQL Backup with mysqldump
sgbd_mysql_backup ()
{
  
  for BASE in ${DATABASE[*]}; do

      # Storage directory
      if [ ! -d ${STORAGE} ]; then
        mkdir -p ${STORAGE}/${TYPE}/${BASE}/${NAME}/logs
      else
        mkdir -p ${STORAGE}/${TYPE}/${BASE}/${NAME}/logs
      fi

      # Last binary log
      LOG_BIN_BEFORE_BACKUP=$(mysql -e "SHOW BINARY LOGS" | tail -n1 | awk '{print $1}')

      SALT=$(date +%d%m%Y%M%S%s%N | md5sum | awk '{print $1}')
      SALT=${SALT:24}
      
      # Make backup logical
      mysqldump --databases ${BASE} --single-transaction -F \
      --result-file=${STORAGE}/${TYPE}/${BASE}/${NAME}/${BASE}-${DATE_TODAY}-${SALT}.sql \
      --log-error=${STORAGE}/${TYPE}/${BASE}/${NAME}/logs/${BASE}-${DATE_TODAY}-error-${SALT}.log \
      --compression-algorithms=zlib \
      --dump-date

      LOG_BIN_DURING_BACKUP=$(mysql -e "SHOW BINARY LOGS" | tail -n1 | awk '{print $1}')

      # Make a new binlog file
      mysql -e "FLUSH LOGS"

      LOG_BIN_AFTER_BACKUP=$(mysql -e "SHOW BINARY LOGS" | tail -n1 | awk '{print $1}')

      cat > ${STORAGE}/${TYPE}/${BASE}/${NAME}/logs/${BASE}-binlog-${SALT}.log <<-LOGFILE
            # Logbin before backup
            /var/lib/mysql/${LOG_BIN_BEFORE_BACKUP}

            # Order to restore the backup:
            1º ==> ${BASE}-${DATE_TODAY}-${SALT}.sql
            2º ==> ${LOG_BIN_DURING_BACKUP}
            3º ==> ${LOG_BIN_AFTER_BACKUP}

            # ****** NOTE *******
            In case this is the last backup prior to a point of failure, it must be followed by all binary logs after it to the point of failure

            # Procedure
            mysql -e "source ${STORAGE}/${TYPE}/${BASE}/${NAME}/${BASE}-${DATE_TODAY}-${SALT}.sql"
            mysqlbinlog /var/lib/mysql/${LOG_BIN_DURING_BACKUP} > ${LOG_BIN_DURING_BACKUP}.sql && mysql -f < ${LOG_BIN_DURING_BACKUP}.sql
            mysqlbinlog /var/lib/mysql/${LOG_BIN_AFTER_BACKUP} > ${LOG_BIN_AFTER_BACKUP}.sql && mysql < ${LOG_BIN_AFTER_BACKUP}.sql
LOGFILE
  done
}

### Build PostgreSQL Backup with pg_dump
sgbd_postgres_backup ()
{
  for BASE in ${DATABASE[*]}; do
      # Storage directory
      if [ ! -d ${STORAGE} ]; then
        mkdir -p ${STORAGE}/${TYPE}/${BASE}/${NAME}/logs
      else
        mkdir -p ${STORAGE}/${TYPE}/${BASE}/${NAME}/logs
      fi

      # Apply permission to user ${USER_POSTGRES} to write
      chown ${USER_POSTGRESQL}. ${STORAGE}/${TYPE}/${BASE}/${NAME}/ -R

      su -c "/usr/bin/pg_dump ${BASE} | ${COMPRESS_ALG} -c \
      > ${STORAGE}/${TYPE}/${BASE}/${NAME}/${BASE}-${DATE_TODAY}.psql.bzip2" \
      -l ${USER_POSTGRESQL}
  done
}


# Load global config and process job file
process_file ()
{
  source "$1"
  for ((c=0; c <$(wc -l ${2} | cut -d' ' -f1); c++)); do
      JOB_DEF[$c]=$(head -n$(($c+1)) "$2" | tail -n1 | cut -d':' -f2)
      echo ${JOB_DEF[$c]} > /tmp/.job_def_${c}
      JOB[$c]="/tmp/.job_def_${c}"
  done
}
process_file $@

# Execute task backup
make_backup ()
{
  for TASK in "$@"; do
      source ${TASK}
      # Validation type of backup
      case ${TYPE} in 
           "default"|"regular_file")
             regular_file_backup
           ;;
           "mysql")
             sgbd_mysql_backup
           ;;
           "postgres")
             sgbd_postgres_backup
           ;;
           *)
             echo "[ERROR]: TYPE is not definied in JOB => ${NAME}!"
             exit 0
           ;;
      esac
  done 
}
# Input job_def file 
make_backup ${JOB[*]}