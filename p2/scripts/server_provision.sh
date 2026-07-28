echo "Hello From SERVER:)"

NODE_IP=192.168.56.110


curl -fL https://get.k3s.io | sh -s - server --node-ip="$NODE_IP" --tls-san="$NODE_IP"
