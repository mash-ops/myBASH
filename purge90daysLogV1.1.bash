#!/bin/bash
#Author : Manjesh.munegowda@sap.com
#Remove/delete logs in /var/log/syslog which are 90days Older
#The current clenaup cron, fails when it hits a bug in current version(4.4.0/4.4.0-38.26.1) of find command
#
#Options : -H = Don't follow links
#          -depth =
#          -noleaf = using to overcome the below find bug/error
#/usr/bin/find: WARNING: Hard link count is wrong for `/var/log/syslog/' (saw only st_nlink=84 but we already saw 82 subdirectories): this may be a bug in your file system driver.  Automatically turning on find's -noleaf option.  Earlier results may have failed to include directories that should have been searched.
#          -type = only process regular file
#          -mtime +90 = modified 90 days ago
#Ver1 ++:  -path = path to the directory
#          -prune = to exclude find from not to decend into the excluded directory
#-H /var/log/syslog/ -depth -noleaf -type f -mtime +90 -exec ls -1 {} \;
#
#Ver:1:Updated 6/12/2018: DC16 has snapshot enabled on /var/log/syslog partition,
#                       : Changed find option -depth from find and added -path and -prune to exclude .snapshot dir (fix until snapshot is disabled)
#
#Ver:1.1:Updated 7/16/2018: filebeat has been run on the syslogServer, when this process is running the server becomes sluggish with high IO wait and the purge scipt stalls
#                         : causing the cron run of the script to be incomplete, before the next cron starts. This update is to verify if an instance is already running and if yes,
#                         : Exit the script logging the details about the previous run.
fnd=/usr/bin/find
sysLogPath=/var/log/syslog
prog=`basename "$0"`
toDay=`/bin/date "+%Y%m%d"`

#if /sbin/pidof -o %PPID -x "$prog" >/dev/null ; then
pid="`/sbin/pidof -o %PPID -x $prog`"

if [ ! -z "${pid// }" ] ; then
  elapsed="`ps -o etime= -p $pid`"
  echo "${toDay} :Warning: Previous Instance of $prog is running from $(echo ${elapsed}|tr -d '[:space:]')" > $sysLogPath/purgelog/PurgePreviousInstance.$toDay
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
  #echo "/bin/mkdir -p /var/log/syslog/purgelog"
fi

#if we have come this far, Let's create a dated log file
#toDay=`/bin/date "+%Y%m%d"`
touch $sysLogPath/purgelog/p90log-$toDay
pLog="$sysLogPath/purgelog/p90log-$toDay"

#echo "value of pLog : $pLog"

#lets find some old Log files to delete (just building list here)

#echo "Building purge list..."
#timed the below and it took longer to build the list, since it uses -exec which 'forks' for each ls .
#$fnd -H $sysLogPath -depth -noleaf -type f -mtime +90 -exec ls -1 '{}' \; 2>&1 >$pLog

#Optamizing to reduce the time take, to build the list. In testing took less than a minute compared to the exec which took 4+ minutes
#$fnd -H $sysLogPath -depth -noleaf -type f -mtime +90 -ls  2>&1 >$pLog
#using -fls instead of redirection, similar to -ls but -fls writes to a file
#$fnd -H $sysLogPath -depth -noleaf -type f -mtime +90 -fls $pLog
#***Commenting out the above line to exclude .snapshot directory from find
#***Currently snapshot is enabled for /var/log/syslog partition in DC16.
#***Below line to Exclude .snapshot in the search, tagging this change as version 1.
#***Exclude (-path <path-to-dir> -prune) will not work, if -depth is not removed from the find
$fnd -H $sysLogPath -noleaf -path "$sysLogPath/.snapshot" -prune -o -type f -mtime +90 -fls $pLog
#echo "purge list Done..."

#lets delete older than 90 days log files
#verifing now, If no purge log required, once confident with the purge list samples, Change the above find to remove instead of build the list
#and comment out or delete this for loop.
for log in `cat $pLog |awk '{print $11}'`
do
 #echo -n "$log :"
 #ls -ld $log
 #echo "Deleting : $log "
 /bin/rm $log
done

#append some stats to the end of log
AfterCleanCurrSpace=`/bin/df -h $sysLogPath`
echo "Syslog Before Clean Up : $currSpace" >> $pLog
echo "Syslog After Clean Up : $AfterCleanCurrSpace" >> $pLog

#echo "Onscreen verify done..."

#### Email the log ###
#/usr/bin/mailx -s "$hst:$pLog" manjesh.munegowda@sap.com < $plog

