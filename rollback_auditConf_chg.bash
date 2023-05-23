#!/bin/bash
#Author:  Manjesh.munegowda@sap.com
#Purpose: Rollback of Audit changes for CHG0119570.output
#tested:  DC8 host 
#09/16/2020: Rolling back the changes /etc/rsyslog.conf.PreAuditFix,
#            /etc/audit/auditd.conf.PreAuditFix & /etc/audit/rules.d/audit.rules.PreAuditFix
#

if [ -f /etc/audit/rules.d/audit.rules.PreAuditFix ]; then 
   sudo /usr/bin/cp -p /etc/audit/rules.d/audit.rules.PreAuditFix /etc/audit/rules.d/audit.rules 
   sudo /usr/bin/rm /etc/audit/rules.d/audit.rules.PreAuditFix
   echo "Backed out /automation/light_audit.rules.PreAuditFix"
fi
if [ -f /etc/rsyslog.conf.PreAuditFix ]; then 
   sudo /usr/bin/cp -p /etc/rsyslog.conf.PreAuditFix /etc/rsyslog.conf
   sudo /usr/bin/rm /etc/rsyslog.conf.PreAuditFix
   echo "Backed out /etc/rsyslog.conf.PreAuditFix"
fi
if [ -f /etc/audit/auditd.conf.PreAuditFix ]; then 
   sudo /usr/bin/cp -p /etc/audit/auditd.conf.PreAuditFix /etc/audit/auditd.conf
   sudo /usr/bin/rm /etc/audit/auditd.conf.PreAuditFix
   echo "Backed out /etc/audit/auditd.conf.PreAuditFix"
fi
sudo /usr/bin/systemctl restart rsyslog >/dev/null 2>&1
sudo /usr/bin/systemctl restart auditd >/dev/null 2>&1
 if [ $? == 0 ]; then
     echo "Successfully: rolledback audit.rules, auditd.conf and rsyslog.conf"
     exit 0
 else
    echo "Issue: restarting auditd service"
    exit 1
 fi
