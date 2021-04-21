#!/bin/bash
#
# ##########################################################################
# +----------------------------------------------------------------------+ #
# |                 Backup Shell                                         | #
# +----------------------------------------------------------------------+ #
# |                                                                      | #
# | Name          : backup-exec.sh                                       | #
# | Function      : Backup of files and SGBD                             | #
# | Version       : 1.0                                                  | #
# | Author        : Jorge Gabriel (Support computer analyst)             | #
# | Email         : jorgegabriel.ti@gmail.com                            | #
# | Creation date : 18-04-2021                                           | #
# | Deploy date   : 19-04-2021, Jorge Gabriel (Support computer analyst) | #
# | Last modified :                                                      | #
# |                                                                      | #
# +----------------------------------------------------------------------+ #
# ##########################################################################
#
# Description:
#
# Algortimo do script :
#
# For each postgres databases listed in the configuration file
# [conf/maker_backup.conf], this programa make:
#
#  1º - Create the backup using the pg_dump program;
#
#  2º - Caculate the backup size based in threshold and fragment
#       it if necessary, making a hash for eac fragment;
#
#  3º - Call the function to assumes the role to consume the resource S3
#
#  4º - Call the function to copy backup to AWS S3
#
#
#  Validations:
#
# ----------------------------------------------------------------------
#
# Historico
#
#     v1.0, Deploy script, [Fri Mar 26 08:40:18 2021] - Jorge Gabriel:
#
#      - Make backup and copy to AWS S3.
#
#
set -e

### Alias eXpands
shopt -s expand_aliases

### Time date config
DATE_TODAY=$(date +%d-%m-%Y)

### Import configs
WORK_DIR='/vagrant_data'
sed -i 's/\r$//' ${WORK_DIR}/conf/backup.conf
source ${WORK_DIR}/conf/backup.conf

### Import functions
for FUNCTION in $(grep -F 'Test: [OK]' -l -r ${WORK_DIR}/function/); do
    sed -i 's/\r$//' ${FUNCTION}
    source ${FUNCTION}
done

# ---
# Build pssh file hosts
PSSH_HOSTS="./.pssh_hosts"

if [ -e ${PSSH_HOSTS} ]; then
    rm -f ${PSSH_HOSTS}
fi

for FILE in ${INCLUDE}; do
    parse ${FILE}
    for ((i=0; i<${QUEUE_DB_LENGHT}; i++)); do 
        JOB[$i]=$(head -n$(($i+1)) .queue.db | tail -n1 | cut -d':' -f2)
        echo "${JOB[$i]}" > .cache
        source .cache
        open_connection 
        rm -f .cache
    done
done

