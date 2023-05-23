#!/bin/bash
#Author : Manjesh.munegowda@sap.com
#Compress logs in /var/log/syslog which are Five (5) days Old
#The current compress cron, fails when it hits a bug in current version(4.4.0/4.4.0-38.26.1) of find command
#Code reuse of purge90daylog.bash
#
#ver:1:Update 6/4/2018: Compressing would stall/fail if the .gz file existed with same file name that is being compressed,
#                       Moving the existing .gz with the time stamp $(date +".%m-%d-%Y-%H:%M:%S.gz")
#                       Added a workaround, needs testing.
#ver:2:Update 6/12/2018:Dc16 has snapshot enabled on /var/log/syslog partition, need to exclude .snapshot from compression
#                       This change is to address this exclusion
#ver:2.1:Update 6/22/2018:on DC12, while compressing encountered below messages, this change is to exclude .nfs file from compression
#                       gzip: /var/log/syslog/ucs0278/.nfs0000000005e5d9ae00001ba8: Device or resource busy
#                       gzip: /var/log/syslog/ucs0278/.nfs0000000005e5d9b700001bad: Device or resource busy
#                       UPON checking, filebeat has this openfile
#                       # lsof /var/log/syslog/ucs0278/.nfs0000000005e5d9ae00001ba8
#                       COMMAND    PID USER   FD   TYPE DEVICE     SIZE/OFF     NODE NAME
#                       filebeat 16980 root 2157r   REG   0,21 182474675417 98949550 /var/log/syslog/ucs0278/.nfs0000000005e5d9ae00001ba8
#Ver:2.2:Updated 7/16/2018: filebeat has been run on the syslogServer, when this process is running the server becomes sluggish with high IO wait and the purge scipt stalls
#                         : causing the cron run of the script to be incomplete, before the next cron starts. This update is to verify if an instance is already running and if yes,
#                         : Exit the script logging the details about the previous run.

#Options : -H = Don't follow links
#          -depth =
#          -noleaf = using to overcome the below find bug/error
#/usr/bin/find: WARNING: Hard link count is wrong for `/var/log/syslog/' (saw only st_nlink=84 but we already saw 82 subdirectories): this may be a bug in your file system driver.  Automatically turning on find's -noleaf option.  Earlier results may have failed to include directories that should have been searched.
#          -type = only process regular file
#          -mtime +90 = modified 90 days ago
#-H /var/log/syslog/ -depth -noleaf -type f -mtime +90 -exec ls -1 {} \;

fnd=/usr/bin/find
sysLogPath=/var/log/syslog
prog=`basename "$0"`
toDay=`/bin/date "+%Y%m%d"`

#if /sbin/pidof -o %PPID -x "$prog" >/dev/null ; then
pid="`/sbin/pidof -o %PPID -x $prog`"

if [ ! -z "${pid// }" ] ; then
  elapsed="`ps -o etime= -p $pid`"
  echo "${toDay} :Warning: Previous Instance of $prog is running from $(echo ${elapsed}|tr -d '[:space:]')" > $sysLogPath/purgelog/CompressPrevInstance.$toDay
  exit 1
fi

#Check if NFS mount /var/log/syslog exists
chkNfs()
{
  /bin/mount |grep $sysLogPath 2>&1 >/dev/null
}

#no NFS mounted syslog, exit!
chkNfs
retVal=$?
if [ $retVal -ne 0 ]; then
  echo "No NFS mounted $sysLogPath found, exiting!"
  exit $retVal
fi

currSpace=`/bin/df -h $sysLogPath`

#check if the purgelog exists, if not create the purgelog directory to keep purged log for each run
if [ ! -d $sysLogPath/purgelog ]; then
  /bin/mkdir -p $sysLogPath/purgelog
fi

#if we have come this far, Let's create a dated log file
#toDay=`/bin/date "+%Y%m%d"`
touch $sysLogPath/purgelog/CompressLog-$toDay
pLog="$sysLogPath/purgelog/CompressLog-$toDay"

#lets find some old Log files to Compress (just building list here)
#30 1 * * 0  (/bin/date && /usr/bin/find  /var/log/syslog/ -type f -mtime +1 -exec /usr/bin/file {} \; | awk -F: '/text/{print $1}'|while read FILE;do /bin/echo -n "Compressing $FILE... ";/usr/bin/gzip -9 $FILE;/bin/echo "DONE";done) >> /var/log/cron_compressed_log

#echo "Building list to compress logs..."
#$fnd -H $sysLogPath -depth -noleaf -type f -mtime +1 -ls |awk -F: '/text/{print $1}' 2>$1 >$pLog
# find /var/log/syslog/ -type f -exec grep -Iq . {} \; -print |grep -v ^$
#$fnd -H $sysLogPath -depth -noleaf -type f -mtime +5 -exec /usr/bin/file '{}' \; |awk -F: '/text/{print $1}' 2>&1 >$pLog
#***Commented out above line to exlude .snapshot, see header for more info
#***Removing -depth from find to exclude .snapshot from compression, when the list is built for compression
$fnd -H $sysLogPath -noleaf -path "$sysLogPath/.snapshot" -prune -o -type f -mtime +5 -exec /usr/bin/file '{}' \; |awk -F: '/text/{print $1}' |grep -v "\.nfs" 2>&1 >$pLog
#echo "Compress list Done..."

#lets compress logs older than 5 days
for log in `cat $pLog |awk '{print $1}'`
do
 #echo -n "$log :"
 #/usr/bin/file $log
 #echo "Compressing : $log "
 dt=$(date +".%m-%d-%Y-%H:%M:%S.gz")
 if [ -f $log.gz ]; then
  #Running into file exists issue while compressing, Renaming the existing .gz with dateTime.gz
  mv $log.gz $log$dt
  echo "Warning: $log.gz existed, moved to $log$dt" 2>&1 >>/tmp/warn
  /usr/bin/gzip -9 $log
 else
  /usr/bin/gzip -9 $log
 fi
done

#append some stats to the end of log
if [ -f /tmp/warn ]; then
 #append to log file and then remove the warn file
 cat /tmp/warn >>$pLog
 /bin/rm /tmp/warn
fi
AfterCleanCurrSpace=`/bin/df -h $sysLogPath`
echo "Syslog Before Compression : $currSpace" >> $pLog
echo "Syslog After Compression : $AfterCleanCurrSpace" >> $pLog

#echo "Onscreen verify done..."

#### Email the log ###
#/usr/bin/mailx -s "$hst:$pLog" manjesh.munegowda@sap.com < $plog


