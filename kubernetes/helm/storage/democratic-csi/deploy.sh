helm repo add democratic-csi https://democratic-csi.github.io/charts/
helm repo update

helm search repo democratic-csi/

helm upgrade --install --create-namespace --values freenas-nfs.yaml --namespace storage nfs democratic-csi/democratic-csi