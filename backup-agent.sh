### TODO:
# Make a function to compress with diferents compressors of data.
# this function should validate the variable COMPRESS_ALG and
# then apply the correct compressor

### TODO
# add function to monitoring disk space and execute backup only there are free space

DATE_TODAY=$(date +%d-%m-%Y)

# Test: [OK]
z_trapper ()
{
  which zabbix_sender > /dev/null 2>&1 && echo "" || echo $(which zabbix_sender)
  ### Parameters
  # 1º: item.key variable
  # 2º: String message
  
  ITEM_KEY="$1"
  shift

  /usr/bin/zabbix_sender \
  -z ${Z_SERVER} \
  -p ${Z_SERVER_PORT} \
  -s ${Z_HOST} \
  -k ${ITEM_KEY} \
  -o "$(cat $1)"
}

# Test: [OK]
recicly ()
{
  if [ "${RETENTION}" -eq '0' ]; then
    find "$1"/ -maxdepth 1 -type f -iname "${NAME}*" -exec rm -f {} \;
  else 
    for DIR in $1; do
      find ${DIR}/ -maxdepth 1 -type f -iname "${NAME}*" -mtime +${RETENTION} -exec rm -f {} \;
      find ${DIR}/logs/ -maxdepth 1 -type f -iname "${NAME}*" -mtime +${RETENTION} -exec rm -f {} \;
    done
  fi
}

# Test: [OK]
hash_checksum ()
{
  if [ "${#@}" -gt 1 ]; then
    ${CHECKSUM_TYPE}sum $1 > "$1".${CHECKSUM_TYPE}
    shift
    for FRAGMENT in "$@"; do
      echo "${1/%_00/}".${CHECKSUM_TYPE}
      ${CHECKSUM_TYPE}sum ${FRAGMENT} >> "${1/%_00/}".${CHECKSUM_TYPE}
    done
  else
    ${CHECKSUM_TYPE}sum $1 > "$1".${CHECKSUM_TYPE}
  fi
}

# Test: [OK]
aws_s3sync ()
{
  # TODO: add fix to error => pload failed: An error occurred (RequestTimeout) when calling the UploadPart operation (reached max retries: 2): Your socket connection to the server was not read from or written to within the timeout period. Idle connections will be closed.
  if [ "${#@}" -gt "2" ]; then
    time for BACKUP in ${@}; do
           time /usr/local/bin/aws s3 cp ${BACKUP} s3://${BUCKET}/${NAME}/${DATE_TODAY}/
         done
  else
    time for BACKUP in ${@}; do
           time /usr/local/bin/aws s3 cp ${BACKUP} s3://${BUCKET}/${NAME}/
         done
  fi
}

# Test: [OK]
aws_assume_role ()
{
   # Unset environment variables
   unset AWS_ACCESS_KEY_ID AWS_SECRET_ACCESS_KEY AWS_SESSION_TOKEN

   # User assume role
   /usr/local/bin/aws sts assume-role --role-arn ${ARN_ROLE} --role-session-name appsMakerAssumeRole \
   > /tmp/.assumeRole.tmp

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
    mkdir -p ${STORAGE}/${TYPE}/${NAME}/logs
  else
    mkdir -p ${STORAGE}/${TYPE}/${NAME}/logs
  fi
  
  # Calculate files size to backup
  FILE_JOB_SIZE="$(du -sck ${FILE[*]} | grep total | awk '{print $1}')"
  STORAGE_SIZE="$(df -k ${STORAGE} | awk '{print $4}' | grep -vi 'available')"

  if [ ${FILE_JOB_SIZE} -ge ${STORAGE_SIZE} ]; then

    # Not run backup and send trapper to Zabbix Server
    JOB_REPORT_STATUS_COMPRESS="FAIL"
    JOB_REPORT_MSG_COMPRESS="[Warning]: There are not free space in disk to make the backup. Starting recycling routine..."
  
    # Run recycle routine
    recicly ${STORAGE}/${TYPE}/${NAME}

    if [ ${FILE_JOB_SIZE} -ge ${STORAGE_SIZE} ]; then
      FREE_DISK_AFTER_RECYCLE="NO"
      JOB_REPORT_MSG_COMPRESS="[Critical]: The backup could not be performed. Recycling routine was not enough. Check the fyle system."
    else 
      FREE_DISK_AFTER_RECYCLE="YES"
    fi 
    
    if [ "${FREE_DISK_AFTER_RECYCLE}" == "YES" ]; then
      tar zcvf ${STORAGE}/${TYPE}/${NAME}/${NAME}-${DATE_TODAY}.tar.gz ${FILE[*]}
      STATUS_COMPRESS="$?"
    fi
  else
    tar zcvf ${STORAGE}/${TYPE}/${NAME}/${NAME}-${DATE_TODAY}.tar.gz ${FILE[*]}
    STATUS_COMPRESS="$?"
  fi 


  # Validation of compress
  if [ "${STATUS_COMPRESS}" -eq '0' ]; then
    JOB_REPORT_STATUS_COMPRESS="OK"
    JOB_REPORT_MSG_COMPRESS="[Info]: The backup was successfully compressed!" 
    
    # Calculating backup size
    BACKUP_SIZE=$(du -b ${STORAGE}/${TYPE}/${NAME}/${NAME}-${DATE_TODAY}.tar.gz | awk '{print $1}')

    # Threshold 100 MiB
    if [ "${BACKUP_SIZE}" -ge '104857600' ]; then
      mkdir -p ${STORAGE}/${TYPE}/${NAME}/fragments/${DATE_TODAY}
    
      # Fragments the backup into files smaller than 512MB each
      split -b 100M -d ${STORAGE}/${TYPE}/${NAME}/${NAME}-${DATE_TODAY}.tar.gz \
      ${STORAGE}/${TYPE}/${NAME}/fragments/${DATE_TODAY}/${NAME}-${DATE_TODAY}.tar.gz_
    
      if [ "$?" -eq '0' ]; then
        JOB_REPORT_STATUS_FRAGMENT="OK"
        JOB_REPORT_MSG_FRAGMENT="[Info]: Backup [${NAME}-${DATE_TODAY}.tar.gz] was fragmented!"
      fi
    
      ### Call functions
      # Checksum # TODO => work with fragments
      hash_checksum ${STORAGE}/${TYPE}/${NAME}/${NAME}-${DATE_TODAY}.tar.gz \
      ${STORAGE}/${TYPE}/${NAME}/fragments/${DATE_TODAY}/${NAME}-${DATE_TODAY}.tar.gz_*
      
      if [ "$?" -eq '0' ]; then
        JOB_REPORT_STATUS_CHECKSUM=OK
        JOB_REPORT_MSG_CHECKSUM=$(cat ${STORAGE}/${TYPE}/${NAME}/fragments/${DATE_TODAY}/${NAME}-${DATE_TODAY}.tar.gz.${CHECKSUM_TYPE})
      fi 

      ### Copy to AWS S3
      if [ ! -z "${ARN_ROLE}" -a ! -z "${AWS_USER}" -a ! -z "${BUCKET}" ]; then
        # AWS Assume Role
        aws_assume_role

        # AWS S3 Sync
        aws_s3sync ${STORAGE}/${TYPE}/${NAME}/fragments/${DATE_TODAY}/${NAME}-${DATE_TODAY}.tar.gz_* \
        ${STORAGE}/${TYPE}/${NAME}/fragments/${DATE_TODAY}/${NAME}-${DATE_TODAY}.tar.gz.${CHECKSUM_TYPE}
      
        if [ "$?" -eq "0" ]; then
          JOB_REPORT_STATUS_COPY="OK"        
          JOB_REPORT_MSG_COPY="[Info]: Backup [${NAME}-${DATE_TODAY}.tar.gz] was successfully copied!"
          rm -rf ${STORAGE}/${TYPE}/${NAME}/fragments/${DATE_TODAY}
        fi
      fi
    else
      ### Call functions
      # Checksum # TODO => work with fragments
      hash_checksum ${STORAGE}/${TYPE}/${NAME}/${NAME}-${DATE_TODAY}.tar.gz
      
      if [ "$?" -eq '0' ]; then
        JOB_REPORT_STATUS_CHECKSUM=OK
        JOB_REPORT_MSG_CHECKSUM=$(cat ${STORAGE}/${TYPE}/${NAME}/${NAME}-${DATE_TODAY}.tar.gz.${CHECKSUM_TYPE})
      fi 

      ### Copy to AWS S3
      if [ ! -z "${ARN_ROLE}" -a ! -z "${AWS_USER}" -a ! -z "${BUCKET}" ]; then
        # AWS Assume Role
        aws_assume_role

        # AWS S3 Sync
        aws_s3sync ${STORAGE}/${TYPE}/${NAME}/${NAME}-${DATE_TODAY}.tar.gz \
        ${STORAGE}/${TYPE}/${NAME}/${NAME}-${DATE_TODAY}.tar.gz.${CHECKSUM_TYPE}
      
        if [ "$?" -eq "0" ]; then
          JOB_REPORT_STATUS_COPY="OK"        
          JOB_REPORT_MSG_COPY="[Info]: Backup [${NAME}-${DATE_TODAY}.tar.gz] was successfully copied!"
        fi
      fi
    fi
  else
    MSG_JOB_REPORT_COMPRESS="FAIL" 
    JOB_REPORT_MSG_COMPRESS="[Critical]: Backup could not be performed!"
  fi

  # Recicly
  recicly ${STORAGE}/${TYPE}/${NAME}
  if [ "$?" -eq '0' ]; then
    JOB_REPORT_STATUS_RECYCLE="OK"
    JOB_REPORT_MSG_RECYCLE="[Info]: Recycling routine successfully executed!"
  else
    JOB_REPORT_STATUS_RECYCLE="FAIL"
    JOB_REPORT_MSG_RECYCLE="[Warnig]: Recycling routine failed!"
  fi 

  # TODO: ADD ZABBIX TRAPPER FUNCTION TO SEND MESSAGES WITH STATUS JOBS
cat > /tmp/.report.txt <<-REPORTFILE
******* Job status report *******
Name         : ${NAME}
--------------------------------------------- 
Compress     : ${JOB_REPORT_MSG_COMPRESS}
Checksum     : ${JOB_REPORT_MSG_CHECKSUM}
Copy         : ${JOB_REPORT_MSG_COPY}
Recycle      : ${JOB_REPORT_MSG_RECYCLE}

# Details
Backup file  : ${NAME}-${DATE_TODAY}.tar.gz
Checksum     : <checksum>
REPORTFILE

  z_trapper ${Z_BACKUP_JOB_STATUS_KEY} /tmp/.report.txt  
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
 # Compress
    tar jcvf ${STORAGE}/${TYPE}/${BASE}/${NAME}/${BASE}-${DATE_TODAY}-${SALT}.sql.${COMPRESS_ALG} \
    ${STORAGE}/${TYPE}/${BASE}/${NAME}/${BASE}-${DATE_TODAY}-${SALT}.sql \
    ${STORAGE}/${TYPE}/${BASE}/${NAME}/logs/${BASE}-binlog-${SALT}.log

    BACKUP_SIZE=$(du -b ${STORAGE}/${TYPE}/${BASE}/${NAME}/${BASE}-${DATE_TODAY}-${SALT}.sql.${COMPRESS_ALG} | awk '{print $1}')

    # Threshold 1GiB
    if [ "${BACKUP_SIZE}" -ge '1073741824' ]; then
       mkdir ${STORAGE}/${TYPE}/${BASE}/${NAME}/fragments
       # Fragments the backup into files smaller than 512MB each
       split -b 512M -d ${STORAGE}/${TYPE}/${BASE}/${NAME}/${BASE}-${DATE_TODAY}-${SALT}.sql.${COMPRESS_ALG} \
       ${STORAGE}/${TYPE}/${BASE}/${NAME}/fragments/${BASE}-${DATE_TODAY}-${SALT}.sql.${COMPRESS_ALG}_

      # Checksum
      hash_checksum ${STORAGE}/${TYPE}/${BASE}/${NAME}/${BASE}-${DATE_TODAY}-${SALT}.sql.${COMPRESS_ALG}

      if [ ! -z "${ARN_ROLE}" -a ! -z "${AWS_USER}" -a ! -z "${BUCKET}" ]; then
        # AWS Assume Role
        aws_assume_role

        # AWS S3 Sync
        aws_s3sync ${STORAGE}/${TYPE}/${BASE}/${NAME}/${BASE}-${DATE_TODAY}-${SALT}.sql.${COMPRESS_ALG} \
        ${STORAGE}/${TYPE}/${BASE}/${NAME}/${BASE}-${DATE_TODAY}-${SALT}.sql.${COMPRESS_ALG}.${CHECKSUM_TYPE}
      fi
    else
      # Checksum
      hash_checksum ${STORAGE}/${TYPE}/${BASE}/${NAME}/${BASE}-${DATE_TODAY}-${SALT}.sql.${COMPRESS_ALG}

      if [ ! -z "${ARN_ROLE}" -a ! -z "${AWS_USER}" -a ! -z "${BUCKET}" ]; then
        # AWS Assume Role
        aws_assume_role

        # AWS S3 Sync
        aws_s3sync ${STORAGE}/${TYPE}/${BASE}/${NAME}/${BASE}-${DATE_TODAY}-${SALT}.sql.${COMPRESS_ALG} \
        ${STORAGE}/${TYPE}/${BASE}/${NAME}/${BASE}-${DATE_TODAY}-${SALT}.sql.${COMPRESS_ALG}.${CHECKSUM_TYPE}
      fi
    fi
  done
  # TODO: ADD ZABBIX TRAPPER FUNCTION TO SEND MESSAGES WITH STATUS JOBS
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

    # Checksum
    hash_checksum ${STORAGE}/${TYPE}/${BASE}/${NAME}/${BASE}-${DATE_TODAY}.psql.bzip2
    
    if [ ! -z "${ARN_ROLE}" -a ! -z "${AWS_USER}" -a ! -z "${BUCKET}" ]; then
      # AWS Assume Role
      aws_assume_role

      # AWS S3 Sync
      aws_s3sync ${STORAGE}/${TYPE}/${BASE}/${NAME}/${BASE}-${DATE_TODAY}.psql.bzip2 \
      ${STORAGE}/${TYPE}/${BASE}/${NAME}/${BASE}-${DATE_TODAY}.psql.bzip2.${CHECKSUM_TYPE}
    fi
  done
  # TODO: ADD ZABBIX TRAPPER FUNCTION TO SEND MESSAGES WITH STATUS JOBS
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