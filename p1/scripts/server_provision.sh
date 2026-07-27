echo "Hello From SERVER:)"

NODE_IP=192.168.56.110
TOKEN_DEFAULT_PATH=/var/lib/rancher/k3s/server/node-token
TOKEN_PATH_IN_SHARED_FOLDER=/vagrant/k3s_node_token

# install the k3s as server, enter the host-ip as 192.168.56.110
curl -fL https://get.k3s.io | sh -s - server --node-ip="$NODE_IP" --tls-san="$NODE_IP"

# wait until token will be generated
while [ ! -f "$TOKEN_DEFAULT_PATH" ]; do
  sleep 1
done

# after the token generated, copy it(from /var/lib/rancher/k3s/server/node-token) into the shared folder /vagrant
cp "$TOKEN_DEFAULT_PATH" "$TOKEN_PATH_IN_SHARED_FOLDER"
