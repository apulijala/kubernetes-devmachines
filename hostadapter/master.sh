# Create DNS entries. Create Host Entries This is executed on Master. 
# DNS names have to be correct 
sudo > /etc/hosts
sudo bash -c 'echo "127.0.0.1   localhost" >> /etc/hosts'  
sudo bash -c 'echo "192.168.50.10 kubernetesmaster" >> /etc/hosts'
sudo bash -c 'echo "192.168.50.11 kubworkerone" >> /etc/hosts'
sudo bash -c 'echo "192.168.50.12 kubworkertwo" >> /etc/hosts'



# Start cluster creation.
sudo kubeadm config images pull
MASTER_IP="192.168.50.10"
POD_CIDR="172.16.0.0/16"
NODENAME="$(hostname -s)"

# check if cluster is already initialized. Otherwise create a cluster
if ! kubectl get nodes  >  /dev/null 2>&1
then 
   sudo kubeadm init --apiserver-advertise-address="$MASTER_IP"  --apiserver-cert-extra-sans="$MASTER_IP" --pod-network-cidr="$POD_CIDR" --node-name "$NODENAME"
fi

# Allow student to adminster cluster.
if [ ! -f "$HOME/.kube" ]
then
   mkdir -p $HOME/.kube
   sudo cp -f /etc/kubernetes/admin.conf $HOME/.kube/config
   sudo chown $(id -u):$(id -g) $HOME/.kube/config
fi

config_path="/vagrant/configs"
if [ -d $config_path ]; then
   rm -f $config_path/*
fi
#create directory and set correct ownership and permissions
sudo mkdir -p "$config_path"  
sudo chown student:student -R  "$config_path" 
sudo chmod 777  "$config_path"

# This config file needs to be there on correct location on host. It will be copied
# to correct location on host machine, by wrapper script.
sudo  cp  /etc/kubernetes/admin.conf "$config_path/kubeconfig"

NETWORKPLGN="https://cloud.weave.works/k8s/net?k8s-version=$(kubectl version | base64 | tr -d '\n')"
# Apply network plugin for weave.
kubectl apply -f  "$NETWORKPLGN"
sleep 5
JOINFILE="/vagrant/configs/join.sh"
[ -f "$/vagrant/configs/join.sh" ] &&  sudo rm /vagrant/configs/join.sh
#kubeadm should run as root and not as student
sudo bash -c 'kubeadm token create --print-join-command > /vagrant/configs/join.sh'