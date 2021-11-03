for host in 192.168.50.10 192.168.50.11 192.168.50.12
do             
  ssh  -l student -i id_rsa "$host" "ls -lrt /tmp/";   
done
