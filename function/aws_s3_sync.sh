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