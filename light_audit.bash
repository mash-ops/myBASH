#!/bin/bash
#Author:  Manjesh.munegowda@sap.com
#Purpose: Push light_audit.rules, check if current rule is same as the new one, if not
#         copy light_audit.rules from /automation and restart service and validate new rules
#tested:  DC4 JH host and build host
#

if [ -f /automation/light_audit.rules ]; then 
 if [ -f /usr/sbin/auditctl ]; then 
   #check auditd service is running
   sudo /usr/bin/systemctl status auditd >/dev/null 2>&1 
   if [ $? == 0 ]; then
     #diff the current rules with light_audit
     sudo /usr/bin/diff /automation/light_audit.rules /etc/audit/rules.d/audit.rules >/dev/null 2>&1
     if [ $? == 0 ]; then
        echo "Looks like it alredy has light_audit.rules applied!"
        exit 0
     else
        if [ -f /etc/audit/rules.d/audit.rules ]; then
           #Backing up current rules
           today=`date +"%m_%d_%Y"`
           sudo /usr/bin/mv /etc/audit/rules.d/audit.rules /etc/audit/rules.d/audit.rules.$today 
           #copying new light_audit.rules
           sudo /usr/bin/cp /automation/light_audit.rules /etc/audit/rules.d/audit.rules
           #Restarting auditd service
           sudo /usr/bin/systemctl restart auditd >/dev/null 2>&1 
           #checking if it has the new rules, on test system it had 53 lines
           NewRule=`/usr/sbin/auditctl -l |wc -l`
           #if [ $NewRule == 153 ]; then
           if [ $NewRule == 53 ]; then
             echo "New light_audit.rules applied!"
             exit 0
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
