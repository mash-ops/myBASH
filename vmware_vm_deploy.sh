#!/bin/bash 
#
# This is vm deploy script for vmware legacy DC's only.
# The code will work only with VMWARE and there is ansbile 
# call from this script to vcenter.
# 
# Please read README before you run this script.
# Questions - Manjesh/David/Ryan/Sunil/Tingting
#
#
#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~#
#
# Subroutines
#
Error() {
   log "ERROR: $1";
   exit 0;
}

Warn() {
   log " WARN: $1";
   #exit 1;
}

Info() {
   log " INFO: $1";
}

log() {
  # logger -t "anfvol_setup.sh `basename $0`" " $1";
  echo  "$(basename $0)" "$1";
}

#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~#
#
# Variables
#
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
TDATE=$(date "+%Y-%m-%d")
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
JsonParamDir=${SCRIPT_DIR}/config
ConsulInfo=${SCRIPT_DIR}/sqlite-dcdetail.csv
AnsiblePath="/home/deployer/ansible/ansible/bin"

#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~#
function Usage(){

cat <<-EOF
        Usage
          $(basename $0) [OPTION]...

        This script is build for VMware environment only.  The ansible call
        Will make using this script to build vm on Vcenter, few other variables
        are pull from sql query with database

        Assumption
        ==========
        All required params to build vms should updated with sqlite, csv database
        required network, subnet, specific VLAN, datacenter, vcluster, dc name
        if the above details updates then only vm call to ansbile with vcetner 
	will be succsssful.

        General Parameters
        ==================

          --help, -h
            checking vm_deploy script help, required vmrelated parameters help.

          --DEBUG, -D
            DRY run method verify your code output before you run final call.

          --datacenter, -d
            to build host required dc as foreign-key to capture other details,
            this filed is very important to setup vm.

          --ipaddress, -i
            to build host required ipaddress

          --HOSTNAME, -H
            to build host required hostname

          --vcenter, -v
            to build host required vcenter details where you want to deploy vm.

          --Os-Verison, -o
            to build host required operating system as SLES12sp3/SLES12sp5 or SLES15SP1.

          Example:-
            ./vmware_vm_deploy.sh -d <datacetner> -i <ipaddress> -H <hostname> -v <VM-dcata-venter-name> -o <OS-Version>
            ./vmware_vm_deploy.sh -d dc4 -i 10.4.198.20 -H dc04testvm01 -v dc04vmvc04 -o sles12sp5 -p aug-20200812
            ./vmware_vm_deploy.sh -d dc4 -v dc04vmvc04 -o sles12sp5 -b /tmp/ipaddress.txt

          Debug option:-
            ./vmware_vm_deploy.sh -d dc8 -i 10.8.198.20 -H dc08testvm01 -v dc08vmvc08 -o sles15sp1 -p aug-20200812 -D 

EOF

}
#
#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~#
# User input check 
#

if [ $# -eq 0 ] ; then
    Usage
    Error "run $(basename $0) --help for the usage."
fi

#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~#
name_servers=$@

export PATH=$PATH:/usr/sbin:/sbin

while getopts 'i:n:g:d:H:u:v:o:p:b:D' arg ; do

    case "${arg}" in

        i ) 

            ip_address="${OPTARG}" ;;

        n ) 

            ip_netmask="${OPTARG}" ;;

        g ) 

            ip_gateway="$OPTARG" ;;

        d ) 

            dc=$(echo ${OPTARG}|tr '[A-Z]' '[a-z]') ;;

        H ) 

            hostname=$(echo ${OPTARG}|tr '[A-Z]' '[a-z]') ;; 
      
        u ) 

            user="${OPTARG}" ;; 

        v ) 

            vcenter="${OPTARG}" ;; 

        o ) 

            osversion=$(echo ${OPTARG}|tr '[a-z]' '[A-Z]') ;;
 
        p )

            patchlevel=$(echo ${OPTARG}) ;;

        D )

            debug="-D" ;;

        b )  

            batch="-b" ;;

        h|help)

            Usage
            Error "Please provide argument listed above" ;;

        *)

            Usage
            Error "Please provide argument listed above" ;;

        esac
done
shift $((OPTIND-1))
#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~#
function DataCenter() {

    if [[ ${dc} == "" ]]; then 
       Usage
       Error "Please provide Datatcenter details to setup VM"
    else
       echo ${dc}
       #return ${dc}     
    fi
        
}

#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~#
function VmHostname(){

   if [[ ${hostname} == "" ]] ; then 
       Usage
       Error "Please provide hostname to setup VM"
   else
       echo ${hostname}
   fi
}
#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~#
function PatchLevel() {

    if [[ ${patchlevel} == "" ]]; then 
       Usage
       Error "Please provide patch details to setup VM"
    else
       echo ${patchlevel}
    fi
        
}

#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~#
function OsType(){

   if [[ ${osversion} == "SLES12SP3" ]] ; then 
       osversion="sdo-sles12sp3-app-${plArg}"
       echo ${osversion}
   elif [[ ${osversion} == "SLES12SP4" ]]; then
       osversion="sdo-sles12sp4-app-${plArg}"
       echo ${osversion}
   elif [[ ${osversion} == "SLES12SP5" ]]; then
       osversion="sdo-sles12sp5-app-${plArg}"
       echo ${osversion}
   elif [[ ${osversion} == "SLES15SP1" ]]; then
       osversion="sdo-sles15sp1-app-${plArg}"
       echo ${osversion}
   else
       Usage
       Error "Non supported os version"
   fi
}
#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~#
function IpAddress(){

   ipchk=$(echo ${ip_address}|grep -E -o "(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)"|wc -l)
   if [[ ${ipchk} -eq 1 ]] ; then 
       echo ${ip_address}
   elif [[ ${ipchk} -ge 2 ]]; then
       #Info "Seems batchmode ipaddress"
       echo ${ip_address}
   else
       Usage
       Error "Please provide IP_Address to setup VM"
   fi
}
#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~#
function IpNetmask(){

   ip_netmask=$(grep ${dcArg} ${ConsulInfo} |awk -F'|' '{print $9}')

   if [[ ${ip_netmask} =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]] ; then 
       echo ${ip_netmask}
       #return  ${ip_netmask}      
   else
       Usage
       Error "Please provide IP_Netmask to setup VM"
   fi

}

#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~#
function IpGateway(){

   ip_gateway=$(grep ${dcArg} ${ConsulInfo} |awk -F'|' '{print $8}')

   if [[ ${ip_gateway} =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]] ; then 
       echo ${ip_gateway}
       #return  ${ip_gateway}      
   else
       Usage
       Error "Please provide IP_Gateway to setup VM"
   fi

}

#
#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~#
# Argument input from function provided by user args.
#
dcArg=$(DataCenter)
ipaddArg=$(IpAddress)
hostnameArg=$(VmHostname)
plArg=$(PatchLevel)
osverArg=$(OsType)
vcArg=${vcenter}
#
# User argument compare with consoul update data with sqlite database
#
dc=$(grep -w ${dcArg} ${ConsulInfo} |awk -F'|' '{print $1}'|sort -u)
vcenter_name=$(grep -w ${dc} ${ConsulInfo}|grep -w ${vcenter}|awk -F'|' '{print $4}')
ad1=$(grep -w ${dc} ${ConsulInfo}|grep -w ${vcenter}|awk -F'|' '{print $2}')
ad2=$(grep -w ${dc} ${ConsulInfo}|grep -w ${vcenter}|awk -F'|' '{print $3}')
dc_vc_cluster=$(grep -w ${dc} ${ConsulInfo}|grep -w ${vcenter}|awk -F'|' '{print $6}')
network=$(grep ${dc} -w ${ConsulInfo}|grep -w ${vcenter}|awk -F'|' '{print $7}')
dc_name=$(grep ${dc} -w ${ConsulInfo}|grep -w ${vcenter}|awk -F'|' '{print $5}')
dc_vc_storage_cluster=$(grep -w ${dc} ${ConsulInfo}|grep -w ${vcenter}|awk -F'|' '{print $10}')
ip_net=$(grep ${dc} -w ${ConsulInfo}|grep -w ${vcenter}|awk -F'|' '{print $9}')
ip_get=$(grep ${dc} -w ${ConsulInfo}|grep -w ${vcenter}|awk -F'|' '{print $8}')
#
#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~#
#
function ansible_deploy() {

if [[ ${dcArg} == ${dc} && ${vcArg} == ${vcenter} && ${ipaddArg} != '' ]] ; then
    Info "Checking Ansible folder and installation"
    if [ -f /home/deployer/ansible/ansible/bin/activate ]; then 
        source ${AnsiblePath}/activate
        Info "Found Ansbile and activated Ansible"
        if [ $? -eq 0 ] ; then 
            Info "Vm build in progress"
            ansible-playbook deploy_vcenter_vm.yml --vault-password-file .vault --extra-vars "new_vmname=${hostnameArg} ip_addr=${ipaddArg} ip_netmask=${ip_net} ip_gateway=${ip_get} hostname=${vcenter_name} datacenter=${dc_name} cluster=${dc_vc_cluster} datastore=${dc_vc_storage_cluster} dns_serv1=${ad1} dns_serv2=${ad2} os_type=${osverArg} net_name=${network}"
        else
            Error "Failed to start Ansible, please check with platform team"
        fi
    else
        Error "Ansible folder is missing ${AnsiblePath} please check with Platform team"
    fi

else
    Error "Missing empty datacenter, ipaddress, hostname or vcenter is missing with input you provided" 
fi 
}
#
#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~#
#
function ansible_debug() {

if [[ ${dcArg} == ${dc} && ${vcArg} == ${vcenter} && ${ipaddArg} != '' ]] ; then
    Info "Checking Ansible folder and installation"
    if [ -f /home/deployer/ansible/ansible/bin/activate ]; then 
        source ${AnsiblePath}/activate
        Info "Found Ansbile and activated Ansible"
        if [ $? -eq 0 ] ; then 
            Info "Vm build in progress"
            echo "new_vmname=${hostnameArg} ip_addr=${ipaddArg} ip_netmask=${ip_net} ip_gateway=${ip_get} os_template=${osverArg} hostname=${vcenter_name} datacenter=${dc_name} cluster=${dc_vc_cluster} datastore=${dc_vc_storage_cluster} dns_serv1=${ad1} dns_serv2=${ad2} os_type=${osverArg}  net_name=${network}"
            ansible-playbook deploy_vcenter_vm.yml --vault-password-file .vault --extra-vars "new_vmname=${hostnameArg} ip_addr=${ipaddArg} ip_netmask=${ip_net} ip_gateway=${ip_get} hostname=${vcenter_name} datacenter=${dc_name} cluster=${dc_vc_cluster} datastore=${dc_vc_storage_cluster} dns_serv1=${ad1} dns_serv2=${ad2} os_type=${osverArg} net_name=${network}" -vvv --check
        else
            Error "Failed to start Ansible, please check with platform team"
        fi
    else
        Error "Ansible folder is missing ${AnsiblePath} please check with Platform team"
    fi

else
    Error "Missing empty datacenter, ipaddress, hostname or vcenter is missing with input you provided" 
fi 
}
#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~#
# Function post deployment of Image
#

function post_deploy() {

ping -c 4 ${ipaddArg}

if [[ $? == 0 ]]; then
    deactivate
    Info "Post image setup in progress: Bootstrap, SSSD, AD etc...."
    export ANSIBLE_HOST_KEY_CHECKING=False
    sshpass -f .vault_pass ansible-playbook -i ${ipaddArg}, --extra-vars "@group_vars/${dcArg}.yml" --ask-pass site.yml -u ccloud
    if [[ $? -eq 0 ]]; then
        Info "Host ${hostnameArg} build Succssfully!"
    else
        Error "Post image setup failed for host ${hostnameArg}"
    fi
else
    deactivate
    Info "Please make sure SUMA registration succssful and run these commands"
    echo "export ANSIBLE_HOST_KEY_CHECKING=False"
    echo "sshpass -f .vault_pass ansible-playbook -i ${ipaddArg}, --extra-vars "@group_vars/${dcArg}.yml" --ask-pass site.yml -u opsadmin"
    Warn "Please verify logs with Vcenter ${vcenter_name}"
    Error "Faild to ping host ${hostnameArg} with ip ${ipaddArg}"
fi
}

#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~#
# ansible-playbook batch_deploy_vcenter_vm.yml --extra-vars "new_vmname_list=['sdovm01','sdovm02'] ip_addr_list=['10.4.198.34','10.4.198.35'] ip_netmask=255.255.255.0 ip_gateway=10.4.198.1 hostname=dc04vmvc04 datacenter=DC04VC04 cluster=DC04-VC04-Cluster14 datastore=DC04_VC04_SAS2SSD_Storage_Cluster14 dns_serv1=10.4.196.10 dns_serv2=10.4.196.46 os_type=SDO-Automation-Template-12sp5 net_name=MGMT-SVCS_198" --check
#
# Batch mode process to call multiple nodes vm build
#

function batch_mode() {

    if [[ ${batch} == "-b" ]]; then
        Info "Building multiple VMs with the batch mode"
        delay=60
        #ipaddlist=$(cat /tmp/somefile|awk '{print $1}'|sed -e ':a;N;$!ba;s/\n/'"','"'/g'|sed -e 's/^/[\'"'/g; s/$/'"']/g')
        #hostlist=$(cat /tmp/somefile|awk '{print $1}'|sed -e ':a;N;$!ba;s/\n/'"','"'/g'|sed -e 's/^/[\'"'/g; s/$/'"']/g')
        #cat /tmp/abcd|awk '{print $1}'|sed -e ':a;N;$!ba;s/\n/'"','"'/g'|sed -e 's/^/['"'/g; s/$/'"']/g'
        xx=$(echo ${ipaddArg}|awk -F',' '{print $1}')
        yy=$(echo ${ipaddArg}|awk -F',' '{print $2}')
        ipaddlist=$(echo "['${xx}','${yy}']")
        ab=$(echo ${hostnameArg}|awk -F',' '{print $1}')
        dc=$(echo ${hostnameArg}|awk -F',' '{print $2}')
        hostlist=$(echo "['${ab}','${dc}']")
        if [[ $? -eq 0 ]]; then
            Info "Building vm with batch mode"
            if [ -f /home/deployer/ansible/ansible/bin/activate ]; then 
                source ${AnsiblePath}/activate
                Info "Found Ansbile and activated Ansible"
                if [ $? -eq 0 ] ; then 
                    Info "Vm build in progress"
                    echo "new_vmname=${hostlist} ip_addr=${ipaddlist} ip_netmask=${ip_net} ip_gateway=${ip_get} hostname=${vcenter_name} datacenter=${dc_name} cluster=${dc_vc_cluster} datastore=${dc_vc_storage_cluster} dns_serv1=${ad1} dns_serv2=${ad2} os_type=${osverArg} net_name=${network} delay=${delay}"
                    #ansible-playbook batch_deploy_vcenter_vm.yml --extra-vars "new_vmname_list=${hostlist} ip_addr_list=${ipaddlist} ip_netmask=${ip_net} ip_gateway=${ip_get} hostname=${vcenter_name} datacenter=${dc_name} cluster=${dc_vc_cluster} datastore=${dc_vc_storage_cluster} dns_serv1=${ad1} dns_serv2=${ad2} os_type=${osverArg} net_name=${network} delay=${delay}"
                    ansible-playbook batch_deploy_vcenter_vm.yml --vault-password-file .vault --extra-vars "new_vmname_list=${hostlist} ip_addr_list=${ipaddlist} ip_netmask=${ip_net} ip_gateway=${ip_get} hostname=${vcenter_name} datacenter=${dc_name} cluster=${dc_vc_cluster} datastore=${dc_vc_storage_cluster} dns_serv1=${ad1} dns_serv2=${ad2} os_type=${osverArg} net_name=${network} delay=${delay}"
                    ipadd=$(echo ${xx},${yy})
                    deactivate
                    Info "Post image setup in progress: Bootstrap, SSSD, AD etc...."
                    export ANSIBLE_HOST_KEY_CHECKING=False
                    #echo ${ipadd}
                    sshpass -f .vault_pass ansible-playbook -i ${ipadd}, --extra-vars "@group_vars/${dcArg}.yml" --ask-pass site.yml -u opsadmin
		    echo "You are pass after post step"
                else
                    Warn "Hosts count v/s ipaddress counts is mismatch"
                    Error "Please verify Hosts and ipaddress again and re-run the script"
                fi
            fi

        fi
    fi
}
 
#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~#
# Main script call
#
if [[ ${debug} == '-D' ]]; then
    Info "Script is running in debug mode, not changes applied"
    ansible_debug
elif [[ $(echo ${ipaddArg}|tr -dc ','|wc -c) -gt 1 ]]; then 
    Info "Batch mode vm deploy"
    batch_mode 
else
    Info "Script will start deploying vm check vcenter logs"
    ansible_deploy
    post_deploy
fi
