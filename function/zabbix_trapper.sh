# Test: [OK]
trapper ()
{
  /usr/bin/zabbix_sender -z "$1" -p "$2" -s "$3" -k "$4" -o "$5"
}