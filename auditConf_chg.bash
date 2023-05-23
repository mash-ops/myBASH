#!/bin/bash
#Author:  Manjesh.munegowda@sap.com
#Purpose: Push light_audit.rules, check if current rule is same as the new one, if not
#         copy light_audit.rules from /automation and restart service and validate new rules
#tested:  DC4 JH host and build host
#09/13/2020: Added option_eql and option_noeql to replace strings in /etc/rsyslog.conf & /etc/audit/auditd.conf
#            adding/replacing => write_logs = no and log_format = ENRICHED in /etc/audit/auditd.conf
#            adding/replacing => local6.*  -/var/log/audit/audit.log in /etc/rsyslog.conf

function option_eql() {
    name=${1//\//\\/}
    value=${2//\//\\/}
    sudo sed -i \
        -e '/^#\?\(\s*'"${name}"'\s*=\s*\).*/{s//\1'"${value}"'/;:a;n;ba;q}' \
        -e '$a'"${name}"' = '"${value}" $3
}

function option_noeql() {
    name=${1//\//\\/}
    value=${2//\//\\/}
    sudo sed -i \
        -e '/^#\?\(\s*'"${name}"'\s*-\s*\).*/{s//\1'"${value}"'/;:a;n;ba;q}' \
        -e '$a'"${name}"'				-'"${value}" $3
}
#option_eql write_logs no /tmp/foo
#option_eql log_format ENRICHED /tmp/foo
#option_noeql local6.* /var/log/audit/audit.log /tmp/bar

if [ -f /automation/light_audit.rules ]; then 
 if [ -f /usr/sbin/auditctl ]; then 
   #check auditd service is running
   sudo /usr/bin/systemctl status auditd >/dev/null 2>&1 
   if [ $? == 0 ]; then
     #diff the current rules with light_audit
     sudo /usr/bin/diff /automation/light_audit.rules /etc/audit/rules.d/audit.rules >/dev/null 2>&1
     if [ $? == 0 ]; then
        echo "Looks like it already has light_audit.rules applied!"
        exit 0
     else
        if [ -f /etc/audit/rules.d/audit.rules ]; then
           #Backing up current rules
           today=`date +"%m_%d_%Y"`
           backout='PreAuditFix'
           sudo /usr/bin/mv /etc/audit/rules.d/audit.rules /etc/audit/rules.d/audit.rules.$backout 
           #copying new light_audit.rules
           sudo /usr/bin/cp /automation/light_audit.rules /etc/audit/rules.d/audit.rules
           #Backing up /etc/audit/auditd.conf
           sudo /usr/bin/cp /etc/audit/auditd.conf /etc/audit/auditd.conf.$backout
             option_eql write_logs no /etc/audit/auditd.conf
             option_eql log_format ENRICHED /etc/audit/auditd.conf
           #Backing up /etc/rsyslog.conf
           sudo /usr/bin/cp /etc/rsyslog.conf /etc/rsyslog.conf.$backout
             option_noeql local6.* /var/log/audit/audit.log /etc/rsyslog.conf
           #Restarting auditd service
           sudo /usr/bin/systemctl restart auditd >/dev/null 2>&1 
           #checking if it has the new rules, on test system it had 53 lines
           NewRule=`/usr/sbin/auditctl -l |wc -l`
           #if [ $NewRule == 242 ]; then
           if [ $NewRule == 157 ]; then
             #restarting rsyslog 
             sudo /usr/bin/systemctl restart rsyslog >/dev/null 2>&1
               if [ $? == 0 ]; then
                sudo /usr/bin/egrep -w ^local6 /etc/rsyslog.conf
               else
                echo "check /etc/rsyslog.conf and check rsyslog service"
                exit 1
               fi
                sudo /usr/bin/egrep -w 'write_logs|log_format' /etc/audit/auditd.conf
               if [ $? != 0 ]; then
                echo "check /etc/audit/auditd.conf for write_logs log_format"
                exit 1
               else
                 echo "Success:New light_audit.rules applied, auditd.conf and rsyslog.conf updated !"
                 echo "        Above are the changes to rsyslog.conf and auditd.conf ! "
                 exit 0
               fi
           else
             echo "Issue: Please manualy check the rules on this `hostname`"
             exit 255
           fi
        else
          echo "/etc/audit/rules.d/audit.rules does not exist!"
          exit 1
        fi
     fi #diff check
  else
   echo "Fatal: Audit service is not running!!"
   exit 1
  fi
 else
   echo "Fatal: /usr/sbin/auditctl file not Found, check audit package is installed!!"
 fi
else
  echo "Fatal: File /automation/light_audit.rules Not Found!!, this is a required file"
  exit 1
fi
