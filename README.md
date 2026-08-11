# Inception-of-Things

Kubernetes cluster setup with K3s, K3d and Argo CD.

```
.
├── p1/          K3s cluster: server + worker (Vagrant, 2 VMs)
├── p2/          K3s + 3 apps behind a host-based Ingress (Vagrant, 1 VM)
├── p3/          K3d + Argo CD, GitOps deployment from GitHub
└── bonus/       GitLab in-cluster (optional)
```

---

## Part 1 — K3s and Vagrant

Two VMs: `aggrigorS` (control-plane, 192.168.56.110) and `aggrigorSW` (worker, 192.168.56.111).

### Run

```bash
cd p1
vagrant up
```

### Verify

```bash
vagrant status                      # both machines running

vagrant ssh aggrigorS
sudo kubectl get nodes -o wide      # 2 nodes, both Ready, correct INTERNAL-IPs
```

Expected: `aggrigors` with role `control-plane`, `aggrigorsw` with role `<none>`,
INTERNAL-IP `192.168.56.110` and `192.168.56.111` (not the NAT address 10.0.2.15).

### Health checks

```bash
free -h                             # swap used should stay near 0
uptime                              # load average below the number of CPUs
sudo systemctl status k3s           # on the server
sudo systemctl status k3s-agent     # on the worker
sudo journalctl -u k3s -f           # live logs
```

### Rebuild from scratch

```bash
vagrant destroy -f && vagrant up
```

---

## Part 2 — K3s and three applications

One VM (`aggrigorS`, 192.168.56.110) running three apps behind a single Ingress.
Routing is by `Host` header: `app1.com` → app1, `app2.com` → app2, anything else → app3.
app2 runs 3 replicas.

### Run

```bash
cd p2
vagrant up
```

Manifests are applied automatically by the provisioning script.

### Verify routing

From the host (PowerShell — note `curl.exe`, since `curl` is an alias for
`Invoke-WebRequest` and does not understand `-H`):

```powershell
curl.exe -H "Host: app1.com" http://192.168.56.110
curl.exe -H "Host: app2.com" http://192.168.56.110
curl.exe http://192.168.56.110
```

From inside the VM:

```bash
curl -H "Host: app1.com" http://192.168.56.110
curl -H "Host: app2.com" http://192.168.56.110
curl http://192.168.56.110
```

Each should return its own response; the third one falls through to app3.

### Verify objects

```bash
vagrant ssh
sudo kubectl get deployments        # app2 must show 3/3
sudo kubectl get pods -o wide
sudo kubectl get svc
sudo kubectl get ingress
sudo kubectl describe ingress       # show the host rules during the defense
```

### Re-apply manifests manually

```bash
sudo kubectl apply -f /vagrant/confs/
sudo kubectl delete -f /vagrant/confs/
```

---

## Part 3 — K3d and Argo CD

A k3d cluster (nodes are Docker containers) with Argo CD watching a public
GitHub repository and deploying the app into the `dev` namespace.

### Run

```bash
cd p3
./scripts/install.sh          # Docker, k3d, kubectl (run once)
./scripts/setup_cluster.sh    # cluster, namespaces, Argo CD, Application
```

If `docker` needs sudo after install, log out and back in, or:

```bash
newgrp docker
```

### Verify

```bash
kubectl get nodes                       # the k3d node
docker ps                               # the same node as a container + serverlb
kubectl config current-context          # should be k3d-part3

kubectl get namespaces                  # argocd, dev
kubectl get pods -n argocd              # ~7 pods, all Running
kubectl get application -n argocd       # Synced / Healthy
kubectl get pods -n dev                 # deployed by Argo CD, not by hand
kubectl get svc -n dev                  # NodePort 30000

curl http://localhost:8888/             # {"status":"ok", "message": "v1"}
```

### Argo CD web UI

Port-forward (keeps the terminal busy — use a separate window):

```bash
kubectl port-forward svc/argocd-server -n argocd 8080:443
```

Open <https://localhost:8080> and accept the self-signed certificate.

Username: `admin`. Password:

```bash
kubectl get secret argocd-initial-admin-secret -n argocd \
  -o jsonpath="{.data.password}" | base64 -d
```

### GitOps demo (v1 → v2)

1. Edit `deployment.yaml` in the application repository, change the image tag
   from `wil42/playground:v1` to `wil42/playground:v2`.
2. Commit and push.
3. Wait — Argo CD polls roughly every 3 minutes. To sync immediately, press
   **Sync** in the UI, or:

```bash
kubectl patch application playground -n argocd --type merge -p '{"operation":{"sync":{}}}'
```

4. Check:

```bash
curl http://localhost:8888/             # {"status":"ok", "message": "v2"}
```

Watch it happen:

```bash
kubectl get application -n argocd -w
kubectl get pods -n dev -w
```

### Rebuild from scratch

```bash
k3d cluster delete part3
./scripts/setup_cluster.sh
```

---

## Troubleshooting

### A pod is not starting

```bash
kubectl describe pod <name> -n <namespace>     # read the Events section
kubectl logs <name> -n <namespace>             # what the app itself says
kubectl logs -f <name> -n <namespace>          # follow
kubectl get events -n <namespace> --sort-by=.lastTimestamp
```

`ContainerCreating` for a long time usually means the image is still being
pulled. `ImagePullBackOff` means it cannot be pulled at all — check the image
name. `Pending` usually means the scheduler cannot fit the pod on the node.

### A service returns an empty reply

```bash
kubectl describe svc <name> -n <namespace>     # Endpoints must not be empty
```

An empty `Endpoints` list means the selector matches no running pod — either
the pod is not ready, or the labels do not match.

### A node is NotReady

```bash
kubectl describe node <name> | grep -A8 Conditions
free -h                                        # is it swapping?
uptime                                         # load vs number of CPUs
sudo journalctl -u k3s --no-pager | tail -30
```

`Kubelet stopped posting node status` almost always means the machine ran out
of resources: the control plane needs 2 CPUs and ~2 GB to stay responsive.

### kubectl cannot reach the cluster

```
The connection to the server localhost:8080 was refused
```

That address means kubectl found no kubeconfig at all (it is the built-in
default). Check:

```bash
ls -la ~/.kube/config
echo $KUBECONFIG
kubectl config get-contexts
k3d cluster list
```

For k3s, the config lives in `/etc/rancher/k3s/k3s.yaml` and needs root —
either use `sudo k3s kubectl`, or copy it:

```bash
sudo cp /etc/rancher/k3s/k3s.yaml ~/.kube/config
sudo chown $(id -u):$(id -g) ~/.kube/config
```

### Vagrant hangs or SSH fails

```bash
vagrant status
vagrant reload                     # try this before destroying
vagrant halt --force
VBoxManage list runningvms         # other VMs may hold port 2222
```

To watch the machine boot, set `v.gui = true` in the provider block temporarily.
The VirtualBox log is at `VirtualBox VMs/<name>/Logs/VBox.log`.

---

## Useful shortcuts

```bash
alias k="kubectl"
alias ksys="kubectl -n kube-system"
```

```bash
kubectl get all -A                             # everything, all namespaces
kubectl get pods -o wide --show-labels         # nodes, IPs and labels
kubectl explain deployment.spec                # field reference
kubectl create deployment x --image=nginx --dry-run=client -o yaml   # scaffold
kubectl apply -f <dir>/ --dry-run=server       # validate before applying
```

Cluster ports in use:

| Part | Host port | Cluster side | Purpose |
|------|-----------|--------------|---------|
| p1   | —         | 6443         | K3s API server |
| p2   | 80        | Traefik      | Ingress routing by Host |
| p3   | 8888      | NodePort 30000 | Application |
| p3   | 8080      | 443          | Argo CD UI (port-forward) |
