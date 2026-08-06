set -e

cd "$(dirname "$0")/.."

echo "WARNING: this will delete and recreate the cluster 'part3'"
k3d cluster delete part3 2>/dev/null || true
k3d cluster create part3 -p "8888:30000@loadbalancer"


kubectl apply -f confs/namespaces.yml
# kubectl apply -f manifests/app.yml

kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml --server-side

echo "Waiting for Argo CD to become ready..."
kubectl wait --for=condition=available --timeout=600s deployment/argocd-server -n argocd

kubectl apply -f confs/application.yml