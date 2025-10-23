#!/usr/bin/env bash 
# Author    : manjeshtm@gmail.com
# Purpose   : Purge /opt/SFTP-root/svc-sftp-ciscoise/home/ISE/CONFIGS 
#             and /opt/SFTP-root/svc-sftp-ciscoise/home/ISE/OPERATIONS 
#             which are older than 2 months
# How to Run: run from cron purge_opt_SFTP.bash
# Cron entry: 00 12 1,15 * * /yourLocation/purge_opt_SFTP.bash (runs every 1st and 15th of every month at Noon)
#
# Declare vars
PATH=/usr/bin:/usr/sbin:/bin:/sbin
fnd=/usr/bin/find
declare -a dirSource=(/opt/SFTP-root/svc-sftp-ciscoise/home/ISE/CONFIGS
/opt/SFTP-root/svc-sftp-ciscoise/home/ISE/OPERATIONS)

mountPoint=/opt/SFTP-root
purgePath=/opt/SFTP-root/svc-sftp-ciscoise/home/ISE/
LogFile=/tmp/$(basename $0).$$
purgeHost=$(hostname -f)
percentUsed=$(df -h --output=pcent ${mountPoint} |tail -n1)
days=$(( ( $(date '+%s') - $(date -d '2 months ago' '+%s') ) / 86400 ))

prog=`basename "$0"`
toDay=`/bin/date "+%Y%m%d"`
email='sendmail'
emailFrom='Your BU<donotreply@yourDoman>'
emailTo='yourRecipient@yourDomain'
emailCc='yourRecipient@yourDomain,yourRecipient1@yourDomain'
emailSubject="Purge files older than 2 months on $(echo ${purgeHost})"

# Build a list of files older than 2 months
#
for fndPath in "${dirSource[@]}"; do
  printf "\nFiles older than 2 months under [${fndPath}] : \n" >> ${LogFile}
  ${fnd} -H ${fndPath} -noleaf -type f -mtime +${days} -ls   >> ${LogFile}
  # Added deletion on Nov8-2024
  ${fnd} -H ${fndPath} -noleaf -type f -mtime +${days} -delete
  #${fnd} -H ${fndPath} -noleaf -type f -mtime +60 -ls   >> ${LogFile}
done

# Email the list of files to purge
#
[ -f "$LogFile" ] && ( 
echo From: ${emailFrom}
echo Subject: ${emailSubject}
echo To: ${emailTo}
echo Cc: ${emailCc}
echo
echo "
Hello Team,

Current usage of [$(printf ${mountPoint})] : $(echo "${percentUsed}") 

Following is the list of files to purge
$(cat ${LogFile})

Thanks,
Manjesh
Note: This report is generated thru cron on host [$(printf ${purgeHost})]" ) | ${email} -t ${emailTo}

#cleanup
[ -f "${LogFile}" ] && \rm ${LogFile}
