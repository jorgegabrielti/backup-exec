# Test: [OK]
backup_agent_apply () {
    # This command is idempotent and validates if the job is already configured in the crontab
    pssh --timeout=0 --hosts=${PSSH_HOSTS} \
    'grep -F "@daily root bash /tmp/backup-agent.sh /tmp/*.conf.db > /dev/null 2>&1" /etc/crontab\
    || echo -e "\n### Backup keeper - Cron job\n\
@daily root bash /tmp/backup-agent.sh /tmp/*.conf.db > /dev/null 2>&1\n\
@daily root bash /tmp/backup_job_discovery.sh > /dev/null 2>&1" \
    >> /etc/crontab'
}