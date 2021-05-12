deploy:
	kubectl apply -f https://raw.githubusercontent.com/open-policy-agent/gatekeeper/release-3.3/deploy/gatekeeper.yaml

opa:
	kustomize build . -o policy.yaml
	kubectl apply -f policy.yaml
