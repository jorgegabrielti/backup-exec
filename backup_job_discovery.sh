#!/bin/bash
source backup.conf.db
FILE=$1

Z_HOST=$(cut -d':' -f2- sample.conf.db | tr -s '[:blank:]' '\n' | grep -E 'Z_HOST' | cut -d'=' -f2)

for JSON in $(cat ${FILE} | tr -s '[:blank:]' '\n' | grep -E 'NAME=' | cut -d'=' -f2 | sort); do
    JSON_FORMAT="${JSON_FORMAT},"'{"{#JOB}":"'${JSON}'"}'
done
echo '{"data":['${JSON_FORMAT#,}' ]}'

# Trigger to discovery jobs
/usr/bin/zabbix_sender -z ${Z_SERVER} -p ${Z_SERVER_PORT} -s "${Z_HOST}" -k backup.job.discovery -o "'{"data":['${JSON_FORMAT#,}' ]}'"