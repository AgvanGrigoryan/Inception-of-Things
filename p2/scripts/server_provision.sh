echo "Hello From SERVER:)"

NODE_IP=192.168.56.110

curl -fL https://get.k3s.io | sh -s - server --node-ip="$NODE_IP" --tls-san="$NODE_IP"


echo "Waiting for k3s cluster..."
while ! k3s kubectl get nodes &>/dev/null; do
  sleep 2
done

echo "Applying manifests..."
k3s kubectl apply -f /vagrant/confs/

echo "Done."