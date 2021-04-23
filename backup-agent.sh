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

  ${CHECKSUM_TYPE}sum "$1"

}

# Test: [OK]
aws_s3sync () {

  BASE=$1
  shift
  if [ ${#@} -gt '2' ]; then
     time for FILE in ${@}; do
              time /usr/local/bin/aws s3 cp ${FILE} s3://${BUCKET}/postgres/${BASE}/$(date +%d-%m-%Y)/
          done
  elif [ ${#@} -eq '2' ]; then
       time /usr/local/bin/aws s3 cp "$1" s3://${BUCKET}/postgres/${BASE}/
       time /usr/local/bin/aws s3 cp "$2" s3://${BUCKET}/postgres/${BASE}/logs/
  fi

}

# Test: [OK]
aws_assume_role () {
   # Unset environment variables
   unset AWS_ACCESS_KEY_ID AWS_SECRET_ACCESS_KEY AWS_SESSION_TOKEN

   # User assume role
   /usr/local/bin/aws sts assume-role --role-arn ${ARN_ROLE} --role-session-name appsMakerAssumeRole > /tmp/.appsMakerAssumeRole.tmp

   # Get secrets
   export AWS_ACCESS_KEY_ID=$(grep -E 'AccessKeyId' /tmp/.appsMakerAssumeRole.tmp | awk '{print $2}' | tr -d '"|,')
   export AWS_SECRET_ACCESS_KEY=$(grep -E 'SecretAccessKey' /tmp/.appsMakerAssumeRole.tmp | awk '{print $2}' | tr -d '"|,')
   export AWS_SESSION_TOKEN=$(grep -E 'SessionToken' /tmp/.appsMakerAssumeRole.tmp | awk '{print $2}' | tr -d '"|,')
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
  done
}
make_backup ${JOB[*]}