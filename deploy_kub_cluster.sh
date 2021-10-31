#!/bin/bash 

function  log() {

   if [[ $# ==  1 ]]; then
        LOGLEVEL="DEBUG"
    else 
        LOGLEVEL="$1"
        shift
   fi
   
   echo "$LOGLEVEL :$@" >> "./kubelog"
   return 1
}

log "Clear existing log"
> "./kubelog"
log "Provisioning VMs  "
./vagrant up

kubeconfiglocation="$HOME/.kube"

log "Clearing  existing ssh keys"
# Get the variables from right ip address and also pass it to playbook.
kubmachines=("192.168.0.120" "192.168.0.121" "192.168.0.122")
for  host in 192.168.0.120 192.168.0.121 192.168.0.122
do
    ssh-keygen -f "/home/arvind/.ssh/known_hosts" -R "$host" > /dev/null 2>&1
done

[ ! -d "$HOME/.ssh" ] && {
    log "Creating ssh folder $HOME/.ssh"
    mkdir -pv "$HOME/.ssh"
}


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

if   ! grep -i kubernetesmaster /home/arvind/.ssh/config   > /dev/null          
then
    cat  <<EOF  >>  /home/arvind/.ssh/config
     
Host kubernetesmaster
HostName 192.168.0.120
User student
Port 22
StrictHostKeyChecking no
IdentityFile "$HOME/kubecluster/student_rsa"


Host kubernetesworkerone
HostName 192.168.0.121
Port 22
User student
StrictHostKeyChecking no
IdentityFile "$HOME/kubecluster/student_rsa"


Host kubernetesworkertwo
HostName 192.168.0.122
Port 22
User student
StrictHostKeyChecking no
IdentityFile "$HOME/kubecluster/student_rsa"
EOF
fi





kubeconfiglocation="$HOME/.kube"
rslt=$(ansible -m command -a "ls -l" all 2>/dev/null)
shopt -s nocasematch
while [[  "$rslt" =~ Failed ]]
do 
    echo "waiting for ssh connection"
    sleep 5
    rslt=$(ansible -m command -a "ls -l" all 2>/dev/null)
done
log "Triggering the ansible playbook to install docker, kubernetes and create cluster"
ansible-playbook playbook.yml

# Todo: Check output from above and then fail problem 

log "Get the join token from master"
kubeadmjoincmd=$(ssh kubernetesmaster kubeadm token create --print-join-command 2> /dev/null | sed -n '/kubeadm/ p')
# Could not get it to work from Ansible. Doing it via shell script. 
log "Joining worker nodes to kubernetes cluster"
for worker in  kubernetesworkerone  kubernetesworkertwo
do 
    ssh "$worker" eval sudo "$kubeadmjoincmd"
done

log "Copy the kube config file to correct location"
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
    count=$(kubectl get nodes | grep -i NotReady     | wc -l)
    # echo "Count of nodes is $count"
done

echo "Cluster Successfully Provisioned"
kubectl get po -n kube-system