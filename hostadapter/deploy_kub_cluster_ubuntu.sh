#!/bin/bash 

##
## Author: Arvind K. Pulijala
## Bash script which is  a wraper, to provision vms using vagrant, install docker and kubernetes on vms. 
## Create Kubernetes cluster, and join worker nodes. 
## Pre requisites: ansible, vagrant, kubectl and Virutal box should be installed. 
## Script automatically installs ansible , vagrant, kubectl above tools if not present . 
## Should work on Mac Machines using OS less than BigSur and Intel  Chips. 

## Get master node.  kubectl get nodes -o wide | grep master | awk '{print $6}'


function  log() {

   if [[ $# ==  1 ]]; then
        LOGLEVEL="DEBUG"
    else 
        LOGLEVEL="$1"
        shift
   fi
   
   echo "$LOGLEVEL :$@" >> "./kubelog"
   #    echo "$LOGLEVEL :$@" 
   return 1
}

log "Clear existing log"
> "./kubelog"


# Install Ansible. 

command -v ansible >/dev/null 2>&1  || { 

    echo "Installing ansible"   
    sudo apt update -y 
    sudo apt install software-properties-common -y
    sudo add-apt-repository --yes --update ppa:ansible/ansible
    sudo apt install ansible -y

}

# Install Virtualbox
command -v virtualbox >/dev/null 2>&1  || { 
    echo "Installing Virtualbox     " 
   
    sudo apt install virtualbox -y
    sudo apt install virtualbox-dkms -y
    sudo dpkg-reconfigure virtualbox-dkms
    sudo dpkg-reconfigure virtualbox    
    sudo modprobe vboxdrv
}

                     
KUBMASTER="192.168.50.10"
KUBWORKERONE="192.168.50.11"
KUBWORKERTWO="192.168.50.12"

KUBMACHINES=("$KUBMASTER" "$KUBWORKERONE" "$KUBWORKERTWO")
log "Kubernetes nodes: ${KUBMACHINES[@]}"

log "Clearing  existing ssh keys"
for  host in "${KUBMACHINES[@]}"
do
    ssh-keygen -f "/home/arvind/.ssh/known_hosts" -R "$host" > /dev/null 2>&1
done

[ ! -d "$HOME/.ssh" ] && {
    log "Creating ssh folder $HOME/.ssh"
    mkdir -pv "$HOME/.ssh"
}

kubeconfiglocation="$HOME/.kube"
[ ! -d "$HOME/kubecluster" ] && {
    log  "Creating directory for holding ssh keys"
    mkdir -pv "$HOME/kubecluster"
} 

[ -f "$HOME/kubecluster/student_rsa" ]  && {
    log "Removing existing ssh key "
    rm  -f  "$HOME/kubecluster/student_rsa"      
}

log "Copy the ssh key to correct location and set correct perms"
cp  ./id_rsa   "$HOME/kubecluster/student_rsa"
chmod 400 "$HOME/kubecluster/student_rsa"

log "Generting entries in ssh config file"
# Need to find a way to retrieve ip address correctly. 
if   ! grep -i kubernetesmaster   "$HOME/.ssh/config"   > /dev/null          
then 
cat  <<EOF  >> "$HOME/.ssh/config"
     
Host kubernetesmaster
HostName "$KUBMASTER"
User student
Port 22
StrictHostKeyChecking no
IdentityFile "$HOME/kubecluster/student_rsa"
ForwardX11 no



Host kubernetesworkerone
HostName "$KUBWORKERONE"
Port 22
User student
StrictHostKeyChecking no
IdentityFile "$HOME/kubecluster/student_rsa"
ForwardX11 no

Host kubernetesworkertwo
HostName "$KUBWORKERTWO"
Port 22
User student
StrictHostKeyChecking no
IdentityFile "$HOME/kubecluster/student_rsa"
ForwardX11 no
EOF

fi

log "Enabling drivers required to enable host adapter."
sudo modprobe vboxnetadp
sudo modprobe vboxnetflt
sudo modprobe vboxdrv

log "Provisioning Virtual Machines in host only network"
./vagrant up

log "Waiting until you get ssh connection"
rslt=$(ansible -m command -a "ls -l" all 2>/dev/null)
shopt -s nocasematch
while [[  "$rslt" =~ Failed ]]
do 
    echo "waiting for ssh connection"
    sleep 5
    rslt=$(ansible -m command -a "ls -l" all 2>/dev/null)
done

# No need to change inventory. 
log "Triggering the ansible playbook to install docker, kubernetes and create cluster"
export PATH="/usr/bin:$PATH"
log "Invoking playbook to provision docker and Kubernetes "
ansible-playbook playbook.yml  

# On Master node create a cluster as student. /vagrant is mapped 
# to current directory.
ssh kubernetesmaster  chmod +x /vagrant/master.sh 2> /dev/null
ssh kubernetesmaster  bash /vagrant/master.sh  2> /dev/null

# On local machine copy the  config file to the correct location on local machine.
log "Copy the kube config file to correct location on local machine."
kubeconfiglocation="$HOME/.kube"
[ ! -d "$kubeconfiglocation" ] && {
    log "Creating Kubeconfig location"
    mkdir -pv "$kubeconfiglocation"
}

cp -f ./configs/kubeconfig "$kubeconfiglocation/config" && chmod 600 "$kubeconfiglocation/config"

# Issue join command via ssh and ssh command copied from above.
readynodes=$(kubectl get nodes | sed -n '2,$ p' | wc -l)
if  [[ "$readynodes" != 3 ]]
then
    for worker in  kubernetesworkerone  kubernetesworkertwo
    do 
        ssh "$worker"  sudo bash /vagrant/configs/join.sh 2> /dev/null
    done
fi


log "Wait for all cluster nodes to be ready"
count=$(kubectl get nodes | grep -i NotReady | wc -l)
# echo "Count of nodes is $count"
while [[ "$count" != 0 ]]
do 
    echo "Waiting for Worker nodes to join the cluster" 
    sleep 40
    count=$(kubectl get nodes | grep -i NotReady | wc -l)
    # echo "Count of nodes is $count"
done

log "Cleaning up"
rm -rf ./configs/   kubeadmresult   kubeconfig


echo "Cluster Successfully Provisioned." 
printf  "Kubernetes master: %s\nKubernetes worker one: %s\nKubernetes worker two: %s\n", "$KUBMASTER" "$KUBWORKERONE" "$KUBWORKERTWO"
echo "Kubernetes system pods. Wait till All system pods are ready to use the cluster. kubectl get po -n kube-system"
kubectl get po -n kube-system
