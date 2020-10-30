kubectl get po -owide | sed -rn 's/^(asb[^ ]+).*/\1/p' | xargs -n1 kubectl logs 
