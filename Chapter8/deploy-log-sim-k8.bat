minikube kubectl -- delete deployment log-simulator --namespace=default
minikube kubectl -- apply -f %LogSimulatorHome%/Kubernetes/log-simulator-deployment.yaml --namespace=default