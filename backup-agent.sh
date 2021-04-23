# Test: [OK]
trapper ()
{
  /usr/bin/zabbix_sender -z "$1" -p "$2" -s "$3" -k "$4" -o "$5"
}

# Test: [OK]
recicly () 
{
for DIR in $(cat base_listdir.txt); do
    find ${DIR} -maxdepth 1 -type f -iname "*.bz2" -mtime +5 -exec rm -f {} \;
    find ${DIR}/logs/ -maxdepth 1 -type f -iname "*.bz2.log" -mtime +5 -exec rm -f {} \;
done
}

# Test: [OK]
postgresql_dump () {

    /usr/bin/pg_dump -U ${USER_POSTGRESQL} "$1" | \
    ${COMPRESS_ALG} -c > ${DIR_BACKUP}/${BASE,,}/${BASE,,}-${DATE_TODAY}.sql.bz2

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

# Load global config and process job file
process_file () {

  source "$1"

  for ((c=0; c <$(wc -l ${2} | cut -d' ' -f1); c++)); do
      JOB_DEF[$c]=$(head -n$(($c+1)) "$2" | tail -n1 | cut -d':' -f2)
      echo ${JOB_DEF[$c]} > .job_def_${c}
      JOB[$c]=".job_def_${c}"
  done

}
process_file $@

# Make backup compress
make_backup () {
  for TASK in "$@"; do
      source ${TASK}
      tar zcvf /tmp/${NAME}.tar.gz ${FILE[*]}
      
      ### Call functions
      
      # Checksum
      hash_checksum /tmp/${NAME}.tar.gz
      
      # AWS Assume Role
      aws_assume_role

      # AWS S3 Sync
      aws_s3sync /tmp/${NAME}.tar.gz /tmp/${NAME}.tar.gz.${CHECKSUM_TYPE}
  done
}
make_backup ${JOB[*]}