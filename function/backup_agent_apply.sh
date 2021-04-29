# Test: [OK]
backup_agent_apply () {
    pssh -P --timeout=0 --hosts=${PSSH_HOSTS} \
    'echo -e "\n### Backup keeper - Cron job\n\
@daily root bash /tmp/backup-agent.sh /tmp/*.conf.db > /dev/null 2>&1" \
    >> /etc/crontab'
}