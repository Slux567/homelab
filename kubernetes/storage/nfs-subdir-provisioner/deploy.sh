kubectl create namespace nfs-storage
helm repo add nfs-subdir-external-provisioner https://kubernetes-sigs.github.io/nfs-subdir-external-provisioner/
helm repo update
helm install nfs-provisioner nfs-subdir-external-provisioner/nfs-subdir-external-provisioner -n nfs-storage -f values.yaml