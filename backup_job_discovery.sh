#!/bin/bash
FILE=$1
for JSON in $(cat ${FILE} | tr -s '[:blank:]' '\n' | grep -E 'NAME=' | cut -d'=' -f2 | sort); do
    JSON_FORMAT="${JSON_FORMAT},"'{"{#JOB}":"'${JSON}'"}'
done
echo '{"data":['${JSON_FORMAT#,}' ]}'