#!/bin/bash 


# User create . Should have sudo privileges without password.
echo "Creating user student with sudo privileges"
! lid -g admin > /dev/null 2>&1  && groupadd admin
! id student > /dev/null 2>&1 &&  useradd -G admin student
echo "%admin ALL=(ALL) NOPASSWD: ALL" > /etc/sudoers.d/admin
echo "password" | passwd --stdin student

# Get ssh connectivity with user student. 
mkdir -pv /home/student/.ssh
chmod 700 /home/student/.ssh/
cp /tmp/id_rsa.pub /home/student/.ssh/authorized_keys
chmod 600 /home/student/.ssh/authorized_keys
chown student:student -R /home/student/.ssh/

# Disable host only adapter. Should have been done in 
# Vagrant file . But don't know how . Disabling host only adapter . 
# Kubernetes will then  bind to bridge network . 
# nmcli device disconnect eth0




