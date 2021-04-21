# Test: [OK]
parse () {

    # Clear queue
    if [ -e "./.queue.db" ]; then
        rm -f ./.queue.db
    fi

    sed -i 's/\r$//' "$1"
    # Identified directives 'job {}'
    export JOB_NUMBERS=$(echo "$(grep -Enc '^job.*{|}' "$1")/2" | bc) 

    # Get job configuration
    j=0
    for ((i=2; i<=$((${JOB_NUMBERS}*2)); i=i+2)); do 
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
        echo "$j:${JOB_CONFIG[$j]}" >> .queue.db
        let "j=j+1"
    done
    QUEUE_DB_LENGHT=$(wc -l .queue.db | cut -d' ' -f1)
}

