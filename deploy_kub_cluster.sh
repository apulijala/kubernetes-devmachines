#!/bin/bash 

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
    sudo modprobe vboxnetflt

    
}

# Installation end
# Getting the machine ip addresss
BRIDGEINTR=$(route -n | awk '$1 ~ /0.0.0.0/ { print $NF}')
log "Get addresses of  machines"
BRIDGEADDR=$(ip a show $BRIDGEINTR  | grep -w "inet" | awk '{print $2}')
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
log "Kubernetes Machines: ${KUBMACHINES[@]}"


# Getting the machine ip addresss
BRIDGEINTR=$(route -n | awk '$1 ~ /0.0.0.0/ { print $NF}')
log "Get addresses of  machines"
BRIDGEADDR=$(ip a show $BRIDGEINTR  | grep -w "inet" | awk '{print $2}')
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
log "Kubernetes machine: ${KUBMACHINES[@]}"

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
BRIDGE=$BRIDGEINTR KUBMASTER=$KUBMASTER KUBWORKERONE=$KUBWORKERONE  KUBWORKERTWO=$KUBWORKERTWO ./vagrant up

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
count=$(kubectl get nodes | grep -i NotReady | wc -l)
# echo "Count of nodes is $count"
while [[ "$count" != 0 ]]
do 
    echo "Waiting for Worker nodes to join the cluster" 
    sleep 40
    count=$(kubectl get nodes | grep -i NotReady | wc -l)
    # echo "Count of nodes is $count"
done

echo "Cluster Successfully Provisioned."
printf  "Kubernetes master: %s\nKubernetes worker one: %s\nKubernetes worker two: %s\n", "$KUBMASTER" "$KUBWORKERONE" "$KUBWORKERTWO"
echo "Kubernetes system pods. Wait till All system pods are ready to use the cluster"
kubectl get po -n kube-system
