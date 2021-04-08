kubectl delete daemonset fluentd --namespace=kube-system
minikube kubectl -- apply -f Kubernetes\fluentd-daemonset.yaml