ß#!/bin/bash


##
## Author: Arvind K. Pulijala
## Thanks to Priya for helping me with her MAC machine to test.
## Bash script which is  a wraper, to provision vms using vagrant, install docker and kubernetes on vms. 
## Create Kubernetes cluster, and join worker nodes. 
## Pre requisites: ansible, vagrant, kubectl and Virutal box should be installed. 
## Script automatically installs ansible , vagrant, kubectl if not present. Virtual box should be manually installed. 

## Should work on Mac Machines using OS less than BigSur and Intel  Chips. Virutal box currently has problems with Apple Mac chip and Monteray. 
## VirtualBox developers are working on a fix



function  log() {

   if [[ $# ==  1 ]]; then
        LOGLEVEL="DEBUG"
    else 
        LOGLEVEL="$1"
        shift
   fi
   
   # echo "$LOGLEVEL :$@" >> "./kubelog"
   echo "$LOGLEVEL :$@" 
   return 1
}

log "Clear existing log"
> "./kubelog"
log "Provisioning VMs  "

command -v brew >/dev/null 2>&1  || {
    echo "brew not found . Installing"
	/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    echo 'eval "$(brew shellenv)"' >> "$HOME/.zprofile"
    echo 'eval "$(brew shellenv)"' >> "$HOME/.profile"
    eval "$(brew shellenv)"

}

# Install Ansible. 
command -v ansible >/dev/null 2>&1  || { 

    echo "Installing ansible"   
    # Download vagrant binary.
    brew install ansible

}

# Install Vagrant.
command -v vagrant >/dev/null 2>&1  || { 
    # Download vagrant binary.
   brew install vagrant
}

# Install Helm Tools.
# Install Vagrant.
# 
command -v kubectl >/dev/null 2>&1  || { 
    # Download vagrant binary.
    brew install bash-completion@2
    brew install kubectl 
    # echo 'source <(kubectl completion bash)' >> “$HOME/.bash_profile
   #  source <(kubectl completion zsh)
   #  echo 'alias k=kubectl' >>~/.zshrc
   # echo 'complete -F __start_kubectl k' >> “$HOME/.zshrc”
   
}

command -v helm >/dev/null 2>&1  || { 
    # Download vagrant binary.
    brew install helm
    # helm completion bash > /usr/local/etc/bash_completion.d/helm

   
}

# Get the  primary network interface which is connecting to network. Kubernetes nodes
# will briged to the ip address. IP addreses of the Kubernetes nodes are automatically computed. 
# with 1 added to the last octed of the primary interface card. Addresses are locked by disabling
# dhcp for the kubernetes network cards  . 

NETWORKCARDDETAILS=$(netstat -rn -f inet | grep default)
BRIDGEINTR=$(echo "$NETWORKCARDDETAILS" | awk '{print $NF}')
log "Get addresses of  machines"
BRIDGEADDR=$(ifconfig "$BRIDGEINTR" | grep -w inet | awk '{print $2}')
log "Removing subnet mask from address"
BRIDGEADDR=${BRIDGEADDR%/*}    
log "Bridge addr: $BRIDGEADDR"
FIRST24=${BRIDGEADDR%.*}       
log "First 24 : $FIRST24"     
LAST8=$(echo "$BRIDGEADDR" | awk -F "." '{print $NF}')
log "Last8 : $LAST8"
                     
KUBMASTER="$FIRST24.$((LAST8 + 1))"
KUBWORKERONE="$FIRST24.$((LAST8 + 2))"
KUBWORKERTWO="$FIRST24.$((LAST8 + 3))"
KUBMACHINES=("$KUBMASTER" "$KUBWORKERONE" "$KUBWORKERTWO")


# INTR="$networkcardtobridge" vagrant up
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


Host kubernetesworkerone
HostName "$KUBWORKERONE"
Port 22
User student
StrictHostKeyChecking no
IdentityFile "$HOME/kubecluster/student_rsa"


Host kubernetesworkertwo
HostName "$KUBWORKERTWO"
Port 22
User student
StrictHostKeyChecking no
IdentityFile "$HOME/kubecluster/student_rsa"
EOF

fi

log "Provisioning Virtual Machine"
BRIDGEINTRWIRELESS="$BRIDGEINTR: Wi-Fi "
BRIDGE=$BRIDGEINTRWIRELESS KUBMASTER=$KUBMASTER KUBWORKERONE=$KUBWORKERONE  KUBWORKERTWO=$KUBWORKERTWO  vagrant up

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
ansible-playbook playbook.yml  --extra-vars "apiaddress=$KUBMASTER  gateway=$FIRST24.1"


# Could not do this completely in playbook.
log "Get the join command from master"
kubeadmjoincmd=$(ssh kubernetesmaster kubeadm token create --print-join-command 2> /dev/null | sed -n '/kubeadm/ p')
# Could not get it to work from Ansible. Doing it via shell script. 
log "Joining worker nodes to kubernetes cluster"

# Issue join command via ssh.
for worker in  kubernetesworkerone  kubernetesworkertwo
do 
    ssh "$worker" eval sudo "$kubeadmjoincmd"
done

log "Copy the kube config file to correct location"
kubeconfiglocation="$HOME/.kube"
[ ! -d "$kubeconfiglocation" ] && {
    log "Creating Kubeconfig location"
    mkdir -pv "$kubeconfiglocation"
}
mv kubeconfig "$kubeconfiglocation/config"  && chmod 600 "$kubeconfiglocation/config"

log "Wait for all master nodes to be ready"
count=$(kubectl get nodes | grep -i NotReady | wc -l | sed 's/^ *//')
# echo "Count of nodes is $count"
while [[ "$count" != 0 ]]
do 
    echo "Waiting for Worker nodes to join the cluster" 
    sleep 40
    count=$(kubectl get nodes | grep -i NotReady | wc -l | sed 's/^ *//')
    # echo "Count of nodes is $count"
done

echo "Cluster Successfully Provisioned."
printf  "Kubernetes master: %s\nKubernetes worker one: %s\nKubernetes worker two: %s\n", "$KUBMASTER" "$KUBWORKERONE" "$KUBWORKERTWO"

echo "Kubernetes system pods. Wait till All system pods are ready to use the cluster !! . use kubectl get po -n kube-system"
kubectl get po -n kube-system
