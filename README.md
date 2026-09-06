# Rancher on Proxmox Virtual Environment

This tutorial aims to show you how to deploy Rancher and multiple downstream
clusters automated by OpenTofu, at the end you will deploy on ArgoCD
cilium L2 Announcement for having a VIP in the workers nodes and a simple
web application.<br />

You will build:

  * upstream cluster: 1 control plane and 1 worker
  * 2 downstream clusters: for each clusters, 3 control planes and 3 workers
  * A VIP on each worker downstream cluster

The kubernetes flavor deployed is RKE2, I also use the ingress controller
traefik, and for CNI I use Cilium.

# PVE

In my example, I have 3 pve nodes defined in rancher-01/04-upstream/main.tf
as follow:

  * pve-01 -> 192.168.1.21
  * pve-02 -> 192.168.1.22
  * pve-03 -> 192.168.1.23

# Upstream cluster

In rancher-01/04-upstream/main.tf is also defined the uptream cluster:

  * local-master-01 -> 192.168.1.31
  * local-worker-01 -> 192.168.1.41

# Downstream clusters

The 2 downstreams clusters are named "andromeda" and "phoenix", and are defined
in rancher-01/05-rancher/main.tf
<br />

The 2 downstreams nodes are defined in 06-downstream/main.tf as follow:

Andromeda cluster:

  * andromeda-master-01 -> 192.168.1.32
  * andromeda-master-02 -> 192.168.1.33
  * andromeda-master-03 -> 192.168.1.34
  * andromeda-worker-01 -> 192.168.1.42
  * andromeda-worker-02 -> 192.168.1.43
  * andromeda-worker-03 -> 192.168.1.44

Phoenix cluster:

  * phoenix-master-01 -> 192.168.1.35
  * phoenix-master-02 -> 192.168.1.36
  * phoenix-master-03 -> 192.168.1.37
  * phoenix-worker-01 -> 192.168.1.45
  * phoenix-worker-02 -> 192.168.1.46
  * phoenix-worker-03 -> 192.168.1.47

# Cilium L2 announcements

As I deploy Cilium L2 announcements through Argocd, we have to set up the
IP range of each cluster that lately holds the VIP of the application, in
modules/rancher/helm-values/argocd-appset.yaml.tftpl I configured the IP range
of cilium L2 as follow:

```
- list:
    elements:
      - name: andromeda
        start_cilium_vip: "192.168.1.101"
        stop_cilium_vip: "192.168.1.109"
      - name: phoenix
        start_cilium_vip: "192.168.1.111"
        stop_cilium_vip: "192.168.1.119"
```

As a result, you would be able to deploy a service in LoadBalancer type by
picking a VIP between 192.168.1.101 and 192.168.1.109 in Andromeda cluster.

# DNS definition

In rancher-01/03-dns/main.tf, I defined some DNS entries for the applications:

  * rancher -> upstream worker node -> 192.168.1.41
  * argocd -> upstream worker node -> 192.168.1.41
  * andromeda -> vip on ingress (service type loadbalancer) on andromeda cluster -> 192.168.1.101
  * phoenix -> vip on ingress (service type loadbalancer) on phoenix clusetr -> 192.168.1.111

I set the vip of andromeda and phoenix pointing on their workers are defined in
modules/rancher/rancher.tf in the rke2-traefik part:

```
ke2-traefik:
  service:
    labels:
      service: web
    spec:
      type: LoadBalancer
    annotations:
      io.cilium/lb-ipam-ips: ${data.terraform_remote_state.dns.outputs.dns_record[each.value.name]}

  tlsStore:
    default:
      defaultCertificate:
        secretName: default-tls-cert
```

# Register the downstream clusters in ArgoCD

In modules/rancher/argocd.tf, I generate a token in Rancher:

```
resource "rancher2_token" "argocd" {
  description = "token for ArgoCD to manage downstream clusters"

  depends_on = [rancher2_setting.agent_tls_mode]
}
```

Then I create a secret in each downstream cluster:

```
resource "kubernetes_secret_v1" "argocd_cluster_secrets" {
  for_each = rancher2_cluster_v2.downstream_clusters

  metadata {
    name      = "argocd-cluster-${each.value.name}"
    namespace = "argocd"

    labels = {
      "argocd.argoproj.io/secret-type" = "cluster"
      "env"                            = "downstream"
    }
  }

  data = {
    name   = each.value.name
    server = "https://rancher.${var.my_domain}/k8s/clusters/${each.value.cluster_v1_id}"

    config = jsonencode({
      bearerToken = rancher2_token.argocd.token
      tlsClientConfig = {
        insecure = false
      }
    })
  }

  type = "Opaque"

  depends_on = [rancher2_token.argocd]
}
```

# Prepare a file containing the configuration

Create a file at ~/terraform/rancher-on-pve/tofu_vars_secrets containing:

```
export TF_VAR_region="eu-west-3"
export TF_VAR_bucket="<XXXX>-rancher-tofu-eu-west-3"
export TF_VAR_key_certificate="tofu/rancher/certificate/tofu.tfstate"
export TF_VAR_key_dns="tofu/rancher/dns/tofu.tfstate"
export TF_VAR_key_upstream="tofu/rancher/upstream/tofu.tfstate"
export TF_VAR_key_rancher="tofu/rancher/rancher/tofu.tfstate"
export TF_VAR_key_downstream="tofu/rancher/downstream/tofu.tfstate"
export TF_VAR_my_domain="<DOMAIN>"
export TF_VAR_my_email="<EMAIL>"
export TF_VAR_pm_user="<PROXMOX USER>"
export TF_VAR_pm_password="<PROXMOX PASS>"
export TF_VAR_nameserver="<DNS SERVER>"
export TF_VAR_gateway="<GATEWAY>"
export TF_VAR_rancher_pass="<RANCHER PASS>"
export TF_VAR_argocd_pass="<ARGOCD PASS>"
export TF_VAR_public_ssh_key="SSH PUBLIC KEY"
```

# Deploying

Create a bucket s3 for storing your OpenTofu states

    $ cd rancher-01/01-bucket
    $ make apply

Request a wildcard certificate to Let's Encrypt

    $ cd ../02-certificate
    $ make apply

Create the DNS entries

    $ cd ../03-dns
    $ make apply

Deploy the upstream cluster

    $ cd ../04-upstream
    $ make apply

Deploy Rancher and ArgoCD on the upstream cluster

    $ cd ../05-rancher
    $ make apply

Wait a few minutes until all pods are up and running

    $ export KUBECONFIG=~/.kube/local
    $ kubectl get po -A

Deploy the downstream clusters

    $ cd ../06-downstream
    $ make apply

# Test

Check the upstream cluster:

    $ export KUBECONFIG=~/.kube/local
    $ kubectl get po -A

Point your browser to https://rancher.<DOMAIN>, then go in 'Cluster Management'
and wait the clusters downstream are in active mode.

Check the downstream clusters:

    $ export KUBECONFIG=~/.kube/andromeda
    $ kubectl get po -A

Do the same with phoenix cluster.

Point your browser to https://argocd.<DOMAIN>, check if the applications
cilium-l2-<CLUSTER> and simple-web-<CLUSTER> are healthy and Synced, if not
try to resync them.

Once all is green on Argocd, check the websites:

    $ curl https://andromeda.<DOMAIN>
    $ curl https://phoenix.<DOMAIN>

# Clean up

For destroying your infrastructure, do it in the reverse order:

    $ cd rancher-01/06-downstream
    $ make destroy
    $ cd ../05-rancher
    $ make destroy
    $ cd ../04-upstream
    $ make destroy
    $ cd ../03-dns
    $ make destroy
    $ cd ../02-certificate
    $ make destroy
    $ cd ../01-bucket
    $ make destroy

# Limitations

  * The downstream clusters are configured in high availability, but the upstream
does not.
  * The ArgoCD token in Rancher has to permission, in a production environment,
make more restrictions.
