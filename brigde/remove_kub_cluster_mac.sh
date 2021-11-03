#!/bin/bash

##
## Author: Arvind K. Pulijala
## destorys all vms. 
##  Removes ssh entries and removes kuberntes config file. 
## installed software ansible, virtualbox, kubectl staty as it is. 

# Remove vagrant. 
vagrant destroy 

# Remove ssh entries from the configuration file. 
sed -i.bak -e '/kubernetesmaster/,+7d' -e '/kubernetesworkerone/,+7d' -e '/kubernetesworkertwo/,+7d' "$HOME/.ssh/config"

# Remove Kubernetes Admin Configuration file to clear the cluster. 
rm -vf $HOME/.kube/config

