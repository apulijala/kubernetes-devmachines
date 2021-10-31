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


