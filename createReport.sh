#!/bin/bash
# Christian Linden, 230308

# This script runs an ansible playbook and generates three reports in form of three columns:
# hostname      rhel-release    kernel-version
# one sorted by hostname, by rhel-release and one by kernel-version. 
# A header shows the date of generation, the latest available kernel and
# the numbers of reached an unreached hosts.
# Read the README.

# commandvars
AWK=$(which awk)
CAT=$(which cat)
CP=$(which cp)
CD=$(which cd)
CUT=$(which cut)
ECHO=$(which echo)
GREP=$(which grep)
LS=$(which ls)
MOUNT=$(which mount)
UMOUNT=$(which umount)
PASTE=$(which paste)
SED=$(which sed)
SORT=$(which sort)
TEE=$(which tee)
TOUCH=$(which touch)
WC=$(which wc)

# filevars
WORKINGDIR=/root/ansible/playbooks/reports
ANSIBLEPLAYBOOK=$(which ansible-playbook)
CURRENTKERNEL7=$WORKINGDIR/helperfiles/current_kernel7.txt
CURRENTKERNEL8=$WORKINGDIR/helperfiles/current_kernel8.txt
CURRENTKERNEL7_LIST=$WORKINGDIR/helperfiles/current_kernel7_list.txt
CURRENTKERNEL7_LIST_FILTERED=$WORKINGDIR/helperfiles/current_kernel7_list_filtered.txt
DATEFILE=$WORKINGDIR/helperfiles/current_date.txt
EMPTYFILE=$WORKINGDIR/helperfiles/emptyfile.txt
TAB=$WORKINGDIR/helperfiles/tab.txt
HEADER=$WORKINGDIR/helperfiles/header.txt
HEADERCOPY=$WORKINGDIR/helperfiles/header_copy.txt
HEADER7=$WORKINGDIR/helperfiles/header7.txt
HEADER8=$WORKINGDIR/helperfiles/header8.txt
HEADER_REACHABLES=$WORKINGDIR/helperfiles/header_reachables.txt
HEADER_UNREACHABLES=$WORKINGDIR/helperfiles/header_unreachables.txt
HOSTFILTER=$WORKINGDIR/helperfiles/hostnames.txt
HOSTREPORT=$WORKINGDIR/resultfiles/GW-ReportSortedByHosts_$(date +%y_%m_%d-%H_%M).txt
RELEASEFILTER=$WORKINGDIR/helperfiles/rhel-releases.txt
REACHABLE_PRE=$WORKINGDIR/helperfiles/reachable_pre.txt
REACHABLE_POST=$WORKINGDIR/helperfiles/reachable_post.txt
RELEASEREPORT=$WORKINGDIR/resultfiles/GW-ReportSortedByRelease_$(date +%y_%m_%d-%H_%M).txt
KERNELFILTER=$WORKINGDIR/helperfiles/kernels.txt
KERNELREPORT=$WORKINGDIR/resultfiles/GW-ReportSortedByKernel_$(date +%y_%m_%d-%H_%M).txt
LINE1=$WORKINGDIR/helperfiles/header_line1.txt
LINE2=$WORKINGDIR/helperfiles/header_line2.txt
LINE3=$WORKINGDIR/helperfiles/header_line3.txt
LINE4=$WORKINGDIR/helperfiles/header_line4.txt
LINE5=$WORKINGDIR/helperfiles/header_line5.txt
LINE6=$WORKINGDIR/helperfiles/header_line6.txt
LINE7=$WORKINGDIR/helperfiles/header_line7.txt
MOUNTPOINT=/mnt
RHEL7REPODIR=/path2ur/rhelx-repo
RHEL8REPODIR=/path2ur/rhely-repo
RHEL7RPMDIR=rhel-7-server-rpms/Packages/k/kernel-3*
RHEL8RPMDIR=rhel-8-for-x86_64-baseos-rpms/Packages/k/kernel-core*
REPORTTARGET=/your/path/here
PLAYBOOK=$WORKINGDIR/get_report.yml
PLAYBOOKLOG=$WORKINGDIR/helperfiles/playbook.log
REPORT=$WORKINGDIR/resultfiles/report.txt
UNREACHABLE=$WORKINGDIR/helperfiles/unreachable.txt

# change into working directory
$CD $WORKINGDIR

# run playbook and save output
$ANSIBLEPLAYBOOK $PLAYBOOK | $TEE $PLAYBOOKLOG

# filter all reachable hosts

# empy filterfiles from previous runs
0>$HOSTFILTER
0>$RELEASEFILTER
0>$KERNELFILTER

$GREP -B1 msg $PLAYBOOKLOG | $GREP -v msg | $GREP ok | $GREP "=>" > $REACHABLE_PRE
$CAT $REACHABLE_PRE | $AWK '{print $2}'| $SED 's/\[//g' | $SED 's/\]//g' > $REACHABLE_POST
# filter hostnames
for i in `$CAT $REACHABLE_POST`
do
  $GREP -A4 "$i\] =>" --no-group-separator $PLAYBOOKLOG | $GREP -v msg | $SED '2!d' | $SED 's/\"//g' | $SED 's/\,//g' >> $HOSTFILTER

  # Redhat-Version filtern und in separate Datei schreiben
  $GREP -A4 "$i\] =>" --no-group-separator $PLAYBOOKLOG | $GREP -v msg | $SED '3!d' | $SED 's/\"//g' | $SED 's/\,//g' >> $RELEASEFILTER

  # Kernelversionen filtern und in separate Datei schreiben
  $GREP -A4 "$i\] =>" --no-group-separator $PLAYBOOKLOG | $GREP -v msg | $SED '4!d' | $SED 's/\"//g' >> $KERNELFILTER
done

# filter unreachable hosts
$GREP 'Failed to connect to the host via ssh' $PLAYBOOKLOG | $AWK '{print $2}' | $SED 's/\[//g' | $SED 's/\]://g' > $UNREACHABLE

# merge the above created filter files
$PASTE $HOSTFILTER $RELEASEFILTER $KERNELFILTER > $REPORT

# mount read-only-nfs share for repo7
$MOUNT 10.135.177.200:$RHEL7REPODIR $MOUNTPOINT

# get latest available rhel7 kernel 
0>$CURRENTKERNEL7_LIST
0>$CURRENTKERNEL7_LIST_FILTERED
$LS -al $MOUNTPOINT/$RHEL7RPMDIR | $AWK '{print $9}' | $AWK -F/ '{print $6}' | $AWK -F- '{print $2"-"$3}' | $SORT -V | $SED 's/\.rpm//g' > $CURRENTKERNEL7_LIST
for i in `$CAT $CURRENTKERNEL7_LIST`
do
  for j in $i
  do
    j2=$($ECHO $j | $CUT -d'-' -f2 | $CUT -d'.' -f2)
    [[ ${j2} =~ ^[0-9] ]] && $ECHO $j >> $CURRENTKERNEL7_LIST_FILTERED
  done
done
$CAT $CURRENTKERNEL7_LIST_FILTERED | $SORT -V | $SED '$!d' > $CURRENTKERNEL7

# umount read-only-nfs share 
$UMOUNT $MOUNTPOINT

# mount read-only-nfs share for repo8 
$MOUNT YOUR.IP.HE.RE:$RHEL8REPODIR $MOUNTPOINT

# get latest available rhel8 kernel 
$LS -al $MOUNTPOINT/$RHEL8RPMDIR | $AWK '{print $9}' | $AWK -F/ '{print $6}' | $AWK -F- '{print $3"-"$4}' | $SORT -V | $SED '$!d' | $SED 's/\.rpm//g' > $CURRENTKERNEL8

# umount read-only-nfs share
$UMOUNT $MOUNTPOINT

# sort report by hostname, release und kernel

$SORT -k1 -r $REPORT > $HOSTREPORT
$SORT -k2 -r $REPORT > $RELEASEREPORT
$SORT -k3 -r $REPORT > $KERNELREPORT

# add timestamp and latest kernel to the report
# get date
ACTUALDATE=`date +%F`

# get number of reachable and unreachable hosts
NUMREACHABLES=$(${WC} -l ${REACHABLE_PRE} | ${AWK} '{print $1}')
NUMUNREACHABLES=$(${WC} -l ${UNREACHABLE} | ${AWK} '{print $1}')
NUMALL=$((${NUMREACHABLES}+${NUMUNREACHABLES}))
PERCENTAGEREACHABLE=$(bc <<< "scale=2;(${NUMREACHABLES}*100)/${NUMALL}")
PERCENTAGEUNREACHABLE=$(bc <<< "scale=2;(${NUMUNREACHABLES}*100)/${NUMALL}")

# generate header with date, not reachable hosts and latest kernel 
$ECHO  " " > $EMPTYFILE
$ECHO -e "\t" >$TAB
$ECHO "latest Kernel RHEL7: " > $HEADER7
$ECHO "latest Kernel RHEL8: " > $HEADER8
$ECHO "Server not reachable: $NUMUNREACHABLES from $NUMALL ($PERCENTAGEUNREACHABLE %)" > $HEADER_UNREACHABLES
$ECHO "Server reachable: $NUMREACHABLES from $NUMALL ($PERCENTAGEREACHABLE %)" > $HEADER_REACHABLES
$ECHO $ACTUALDATE > $DATEFILE
$PASTE $DATEFILE $EMPTYFILE $EMPTYFILE > $LINE1
$PASTE $TAB $TAB $HEADER7 $CURRENTKERNEL7 > $LINE2
$PASTE $TAB $TAB $HEADER8 $CURRENTKERNEL8 > $LINE3
$PASTE $EMPTYFILE $EMPTYFILE $EMPTYFILE > $LINE4
$PASTE $HEADER_UNREACHABLES $EMPTYFILE $EMPTYFILE > $LINE5
$PASTE $EMPTYFILE $UNREACHABLE $EMPTYFILE > $LINE6
$PASTE $HEADER_REACHABLES $EMPTYFILE $EMPTYFILE > $LINE7
$CAT $LINE1 $LINE2 $LINE3 $LINE4 $LINE5 $LINE4 $LINE6 $LINE4 $LINE7 $LINE4 > $HEADER
$CP $HEADER $HEADERCOPY

# add header to report
$ECHO "`$CAT $HOSTREPORT >> $HEADERCOPY`"
$CP $HEADERCOPY $HOSTREPORT
$CP $HEADER $HEADERCOPY
$ECHO "`$CAT $RELEASEREPORT >> $HEADERCOPY`"
$CP $HEADERCOPY $RELEASEREPORT
$CP $HEADER $HEADERCOPY
$ECHO "`$CAT $KERNELREPORT >> $HEADERCOPY`"
$CP $HEADERCOPY $KERNELREPORT

# copy reports to nfs share

# mount write-nfs share
$MOUNT $IP:$PATH $MOUNTPOINT

$CP -p $HOSTREPORT $MOUNTPOINT
$CP -p $RELEASEREPORT $MOUNTPOINT
$CP -p $KERNELREPORT $MOUNTPOINT

# umount nfs share 
$UMOUNT $MOUNTPOINT
