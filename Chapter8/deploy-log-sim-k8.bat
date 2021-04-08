minikube kubectl -- delete deployment log-simulator --namespace=default
minikube kubectl -- apply -f %LogSimulatorHome%\LogGenerator\Kubernetes\log-simulator-deployment.yaml