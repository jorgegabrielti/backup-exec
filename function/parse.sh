# Test: [OK]
parse () {

    # Client config db
    if [ -e "${FILE}.db" ]; then
        rm -f ${FILE}.db
    fi
    
    # Remove caracteres imcompatible with Linux Systems
    sed -i 's/\r$//' ${FILE}

    # Identified directives 'job {}'
    export JOB_NUMBERS=$(echo "$(grep -Enc '^job.*{|}' "${FILE}")/2" | bc) 

    # Get job configuration
    j=0
    for ((i=2; i<=$((${JOB_NUMBERS}*2)); i=i+2)); do 

        # Extracting the intervals 'job {}'
        INTERVAL[$j]=$(grep -En '^job.*{|}' "$1" \
        | head -n$i \
        | tail -n2 \
        | cut -d':' -f1 \
        | paste -s \
        | tr -s '[:blank:]' ',')
        
        JOB_CONFIG[$j]=$(sed ''${INTERVAL[$j]}'!d' "$1" \
        | grep -Ev '^job.*{|}' \
        | tr -d '[:cntrl:]' \
        | tr -s '[:blank:]' ' ')
        echo "$j:${JOB_CONFIG[$j]}" >> ${FILE}.db
        let "j=j+1"
    done
}

