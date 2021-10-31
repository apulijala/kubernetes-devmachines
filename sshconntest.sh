for host in 192.168.0.120 192.168.0.121 192.168.0.122;   
do             
  ssh  -l student -i id_rsa "$host" "ls -lrt /tmp/";   
done
