# Test: [OK]
backup_agent_apply () {
    pssh -P --timeout=0 --hosts=${PSSH_HOSTS}  'bash -x /tmp/backup-agent.sh /tmp/*.conf.db'
}