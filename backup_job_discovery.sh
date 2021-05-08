#!/bin/bash
source backup.conf.db
FILE=$1

Z_HOST=$(zabbix_agentd --help | grep default | cut -d':' -f2 | tr -d '"|)|(' | xargs grep -E '^Hostname' | cut -d'=' -f2)


for JSON in $(cat ${FILE} | tr -s '[:blank:]' '\n' | grep -E 'NAME=' | cut -d'=' -f2 | sort); do
    JSON_FORMAT="${JSON_FORMAT},"'{"{#JOB}":"'${JSON}'"}'
done

# Trigger to discovery jobs
/usr/bin/zabbix_sender -z ${Z_SERVER} -p ${Z_SERVER_PORT} -s "${Z_HOST}" -k backup.job.discovery -o '{"data":['${JSON_FORMAT#,}' ]}'