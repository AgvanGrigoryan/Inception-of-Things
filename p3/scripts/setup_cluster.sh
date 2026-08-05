echo "WARNING: this will delete and recreate the cluster 'part3'"
k3d cluster delete part3 2>/dev/null || true
k3d cluster create part3 -p "8888:30000@loadbalancer"


kubectl apply -f confs/namespaces.yml
kubectl apply -f manifests/app.yml