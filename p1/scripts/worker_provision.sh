echo "Hello From WORKER:)"

NODE_IP=192.168.56.111
TOKEN_PATH=/vagrant/k3s_node_token
SERVER_URL=https://192.168.56.110:6443

# wait until k3s_node_token will be ready(copied)
while [ ! -f $TOKEN_PATH ]; do
    sleep 1
done


# install the k3s as agent, server is 192.168.56.110, take server token from shared folder(/vagrant)
curl -sfL https://get.k3s.io | K3S_URL="$SERVER_URL" K3S_TOKEN=$(cat "$TOKEN_PATH") sh -s - agent --node-ip="$NODE_IP"