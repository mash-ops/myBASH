#!/bin/bash
#Purpose   : preCheck on a rhel client, before joining the client to Active Directory thru realm join
#Reference : https://access.redhat.com/solutions/5444941
#Author    : manjesh@stanfordchildrens.org
#How to use: bash ActiveDirectory_preCheck.bash
#Tested on : GNU bash, version 5.1.8(1)-release (x86_64-redhat-linux-gnu)
#Config    : Set the varialbe REALM_DOMAIN to match your realm
#Required  : Netcat (nc) and dig are prerequisite
#
#set -e

# === COMMAND_CHECK ===
if command -v nc >/dev/null 2>&1; then
  echo "Found Netcat (nc)"
else
  echo "Netcat (nc) not Found, pre check failed"
  exit 2
fi

# === CONFIG ===
REALM_DOMAIN="YourRealm"
LOG_FILE="AD_preCheck.log"
HTML_FILE="AD_preCheck_report.html"
JSON_FILE="AD_preCheck.json"
TEMP_JSON="/tmp/_AD_preCheck.json"
EMAIL_TO="manjesh@stanfordchildrens.org"
EMAIL_FROM="DoNotReply@yourDomain"
EMAIL_SUBJECT="📋 Active Directory Pre Check on $(hostname)"
LOGIN_USER="$(whoami)"
SRV_LDAP_TCP="_ldap._tcp.${REALM_DOMAIN}"
AD_SERVERS=( $(dig +short SRV ${SRV_LDAP_TCP} |awk '{print $4}'|grep -v epcpdc) )
SRV_KERBEROS_TCP="_kerberos._tcp.${REALM_DOMAIN}"
SRV_KERBEROS_UDP="_kerberos._udp.${REALM_DOMAIN}"

DNS_PORT=53
LDAP_PORT=389
LDAPS_PORT=636
KERBEROS_PORT=88
KERBEROS_KADMIN_PORT=464
AD_GLOBAL_TCP_PORT=3268
AD_GLOBAL_TCP_SSL_PORT=3269
NTP_PORT=123

# Recommended thresholds
OPEN_FILES_MIN=200000
USER_PROCESS_MIN=10240
SIG_PENDING_MIN=256966
MAP_COUNT_MIN=262144
MEM_MIN_GB=4
CPU_MIN=2

# === Check if AD server, array is empty ===
if [[ ${#AD_SERVERS[@]} -eq 0 ]]; then
   echo "☠️  Fatal empty AD servers : 
            Hint: make sure your DNS can resolve SRV record ${SRV_LDAP_TCP}
                  example : 1) host -t srv ${SRV_LDAP_TCP}
                            2) dig +short SRV ${SRV_LDAP_TCP}
                            3) nslookup -q=srv ${SRV_LDAP_TCP}
                  and try again"
   exit 2
fi

# === INIT OUTPUT ===
echo "🔍 Active Directory Pre Check from $(hostname -f) $(date),  Running as user: $LOGIN_USER" 
echo "🔍 Active Directory Pre Check - $(date), Running as user: $LOGIN_USER" > "$LOG_FILE"
echo "{" > "$TEMP_JSON"

log() { echo -e "\t$1" | tee -a "$LOG_FILE" ; }
json_entry() {
  echo "  \"$1\": \"$2\"," >> "$TEMP_JSON"
}

section() {
  echo -e "\n🌟 $1" | tee -a "$LOG_FILE"
}

check_threshold() {
  KEY="$1"
  VALUE="$2"
  MIN="$3"
  if (( VALUE < MIN )); then
    log "$KEY: $VALUE ⚠️  (below recommended: $MIN)"
    json_entry "$KEY" "$VALUE (LOW)"
  else
    log "$KEY: $VALUE ✅"
    json_entry "$KEY" "$VALUE"
  fi
}

check_dns_srv() {
  KEY="$1"
  if [[ $(dig +short SRV $1 |wc -l) -gt 0 ]]; then 
    dns_output=$(dig +short SRV $1)
    log "$KEY: $dns_output ✅"
    json_entry "$KEY" "$dns_output"
  else
    log "$KEY:⚠️  (unable to resolve : $1)"
    json_entry "$KEY" "$dns_output"
  fi
}

check_port() {
  OPTION="$1"
  HOSTNAME="$2"
  PORT="$3"
  nc $OPTION $HOSTNAME $PORT >/dev/null 2>&1 
  if [ "$?" -eq 0 ]; then
    ncat_output=$( (nc $OPTION $HOSTNAME $PORT 2>&1 |grep Connected ) )
    log "$HOSTNAME: $ncat_output ✅"
    json_entry "$HOSTNAME" "$ncat_output"
  elif [ "$?" -eq 1 ]; then
    ncat_output=$( (nc $OPTION $HOSTNAME $PORT 2>&1 |egrep 'refused|TIMEOUT' ) )
    log "$HOSTNAME: Port: $PORT ⚠️  ( $ncat_output )"
    json_entry "$HOSTNAME" "$ncat_output"
  fi
}

# === CHECKS ===

# Check DNS Service record (SRV) lookup
section "DNS lookup if AD is resolving"

log "srv_ldap_tcp: $SRV_LDAP_TCP"
check_dns_srv "$SRV_LDAP_TCP"

log "srv_kerberos_tcp: $SRV_KERBEROS_TCP"
check_dns_srv "$SRV_KERBEROS_TCP"

log "srv_kerberos_udp: $SRV_KERBEROS_UDP"
check_dns_srv "$SRV_KERBEROS_UDP"

if [[ ${#AD_SERVERS[@]} -eq 0 ]]; then
  log "AD Server list is empty: Check '_ldap._tcp.YourRealm' Service records in DNS, returns all AD in realm"
  exit 2
else 
  section "Discovered Active Directory servers : "
  echo "${AD_SERVERS[@]}" | tr ' ' '\n' | nl |tee -a "$LOG_FILE"
  echo >> "$LOG_FILE"
  for ad_servers in ${AD_SERVERS[@]}; do
    echo >> "$LOG_FILE"
    # Check all AD servers for ports
    echo "🔍 Checking AD server - [$ad_servers] for required ports are reachable from $(hostname -f)" |tee -a "$LOG_FILE"

    # Check AD ports are open
    section "Checking AD DNS Port is Reachable"

    log "dns_tcp_port_$DNS_PORT: $ad_servers"
    check_port "-zv -w 1" "$ad_servers" $DNS_PORT

    log "dns_udp_port_$DNS_PORT: $ad_servers"
    check_port "-zuv" "$ad_servers" $DNS_PORT

    # Check AD LDAP ports are open
    section "Checking AD LDAP/s Port is Reachable"

    log "ldap_tcp_port_$LDAP_PORT: $ad_servers"
    check_port "-zv -w 1" "$ad_servers" $LDAP_PORT

    log "ldap_udp_port_$LDAP_PORT: $ad_servers"
    check_port "-zuv" "$ad_servers" $LDAP_PORT

    log "ldaps_tcp_port_$LDAPS_PORT: $ad_servers"
    check_port "-zv -w 1" "$ad_servers" $LDAPS_PORT

    # Check AD kerberos ports are open
    section "Checking AD Kerberos Port is Reachable"

    log "kerberos_tcp_port_$KERBEROS_PORT: $ad_servers"
    check_port "-zv -w 1" "$ad_servers" $KERBEROS_PORT

    log "kerberos_udp_port_$KERBEROS_PORT: $ad_servers"
    check_port "-zv" "$ad_servers" $KERBEROS_PORT

    # Check AD kerberos Kadmin ports are open
    section "Checking AD Kerberos Kadmin Port is Reachable"

    log "kerberos_kadmin_tcp_port_$KERBEROS_KADMIN_PORT: $ad_servers"
    check_port "-zv -w 1" "$ad_servers" $KERBEROS_KADMIN_PORT

    log "kerberos_kadmin_udp_port_$KERBEROS_KADMIN_PORT: $ad_servers"
    check_port "-zv" "$ad_servers" $KERBEROS_KADMIN_PORT

    # Check AD Global Catalog ports are open
    section "Checking AD Global Catalog Port is Reachable"

    log "global_catlog_tcp_port_$AD_GLOBAL_TCP_PORT: $ad_servers"
    check_port "-zv -w 1" "$ad_servers" $AD_GLOBAL_TCP_PORT

    log "global_catlog_ssl_tcp_port_$AD_GLOBAL_TCP_SSL_PORT: $ad_servers"
    check_port "-zv -w 1" "$ad_servers" $AD_GLOBAL_TCP_SSL_PORT

    # Check AD NTP ports are open (Optional)
    section "Checking AD NTP Port is Reachable (Optional)"

    log "ntp_udp_port_$NTP_PORT: $ad_servers"
    check_port "-zuv" "$ad_servers" $NTP_PORT
   echo
   done
  fi

##check_version python3 "Python"
#check_version /ieclusterfs/mysql/mysql/bin/mysql "mySQL"

# Finalize JSON
sed -i '$ s/,$//' "$TEMP_JSON"
echo "}" >> "$TEMP_JSON"
mv "$TEMP_JSON" "$JSON_FILE"

# === Generate HTML Report ===
generate_html_report() {
  {
    echo "<html><head><title>Active Directory Pre Check </title>"
    echo "<style>
      body { font-family: Arial, sans-serif; margin: 20px; }
      .warn { color: red; font-weight: bold; }
      .ok { color: green; font-weight: bold; }
      pre { background: #f4f4f4; padding: 10px; border: 1px solid #ccc; }
    </style></head><body>"
    echo "<h1>Active Directory Pre Check - $(hostname)</h1>"
    echo "<p><b>Date:</b> $(date)</p>"
    echo "<pre>"

    while IFS= read -r line; do
      if echo "$line" | grep -q "⚠️"; then
        echo "<span class='warn'>$line</span>"
      elif echo "$line" | grep -q "✅"; then
        echo "<span class='ok'>$line</span>"
      else
        echo "$line"
      fi
    done < "$LOG_FILE"

    echo "</pre>"
    echo "</body></html>"
  } > "$HTML_FILE"
  echo
  log "📄 HTML report generated: $(pwd)/$HTML_FILE"
}

# === Done ===
section "✅ Active Directory Pre Check Run" 
log "🎉 Completed: $(date)"
log "Report saved: $(pwd)/$HTML_FILE" 
log "JSON saved: $(pwd)/$JSON_FILE"
log "Note: Review the report with this symbol ⚠️  for issues" 

# === Send Email ===
if command -v sendmail >/dev/null 2>&1; then
   log "📧 Email sent to $EMAIL_TO"
   generate_html_report
   send_email_report() {
   (
    echo "From: $EMAIL_FROM"
    echo "To: $EMAIL_TO"
    echo "Subject: $EMAIL_SUBJECT"
    echo "MIME-Version: 1.0"
    echo "Content-Type: text/html"
    echo ""
    #cat "$JSON_FILE"
    cat "$HTML_FILE"
   ) | /usr/sbin/sendmail -t
  }
  send_email_report
else
  log "⚠️  [sendmail] command not found, skipping sending generated report via Email" 
  generate_html_report
fi
