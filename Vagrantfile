# Configure Kubernetes Master.  SSH config file. 
Vagrant.configure("2")  do |config|
    config.vm.define "master" do |master|
        master.vm.hostname = "kubernetesmaster"
        master.vm.box = "geerlingguy/centos7"
        master.vm.provision "file", source: "./id_rsa.pub", destination: "/tmp/id_rsa.pub"
        master.vm.provision "shell", path: "set_up_ssh.sh"
        master.vm.network "public_network", 
            bridge: "Intel(R) 82579LM Gigabit Network Connection",
            ip: "192.168.0.120" # Not working . Need to make changes via nmcli . 
        master.vm.provider "virtualbox" do |v|
            v.name =  "kubernetesmaster"
            v.memory = 4096
            v.cpus = 2
        end
    end

    # Configuration kubworker one
    config.vm.define "kubworkerone" do |kubworkerone|
        kubworkerone.vm.hostname = "kubworkerone"
        kubworkerone.vm.box = "geerlingguy/centos7"
        kubworkerone.vm.provision "file", source: "./id_rsa.pub", destination: "/tmp/id_rsa.pub"
        kubworkerone.vm.provision "shell", path: "set_up_ssh.sh"
        kubworkerone.vm.network "public_network", 
            bridge: "Intel(R) 82579LM Gigabit Network Connection",
            ip: "192.168.0.121" 
            kubworkerone.vm.provider "virtualbox" do |v|
            v.name =  "kubworkerone"
            v.memory = 2048
            v.cpus = 2
        end
    end

    # Configuration kubworker two
    config.vm.define "kubworkertwo" do |kubworkertwo|
        kubworkertwo.vm.hostname = "kubworkertwo"
        kubworkertwo.vm.box = "geerlingguy/centos7"
        kubworkertwo.vm.provision "file", source: "./id_rsa.pub", destination: "/tmp/id_rsa.pub"
        kubworkertwo.vm.provision "shell", path: "set_up_ssh.sh"
        kubworkertwo.vm.network "public_network", 
            bridge: "Intel(R) 82579LM Gigabit Network Connection",
            ip: "192.168.0.122" 
            kubworkertwo.vm.provider "virtualbox" do |v|
            v.name =  "kubworkertwo"
            v.memory = 2048
            v.cpus = 2
        end
    end
end    
