minikube kubectl -- delete configmap fluentd-conf --namespace=kube-system
minikube kubectl -- create configmap fluentd-conf --from-file=Fluentd/custom.conf --namespace=kube-system