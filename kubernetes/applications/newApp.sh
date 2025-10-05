#!/bin/bash
# filepath: kubernetes/applications/create_service.sh


read -p "Enter the service name: " SERVICE

DIR="./$SERVICE/"
mkdir -p "$DIR"

# Bwsecret YAML
cat > "$DIR/bwsecret.yaml" <<EOF
apiVersion: k8s.bitwarden.com/v1
kind: BitwardenSecret
metadata:
  name: bw-${SERVICE}-secret
  namespace: $SERVICE
spec:
  secretName: ${SERVICE}-secret
  organizationId: "effc79b3-9414-44ef-b833-b2ca0100595e"
  authToken:
    secretName: bw-auth-token
    secretKey: token

  map:
    - secretKeyName: SECRET_1
      bwSecretId: "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx" 
    - secretKeyName: SECRET_2
      bwSecretId: "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"

EOF

# Namespace YAML
cat > "$DIR/namespace.yaml" <<EOF
apiVersion: v1
kind: Namespace
metadata:
  name: $SERVICE
---
apiVersion: traefik.io/v1alpha1
kind: Middleware
metadata:
  name: https-redirect
  namespace: $SERVICE
spec:
  redirectScheme:
    scheme: https
    permanent: true
EOF

# ConfigMap YAML
cat > "$DIR/configmap.yaml" <<EOF
apiVersion: v1
kind: ConfigMap
metadata:
  name: ${SERVICE}-config
  namespace: $SERVICE
data:
  EXAMPLE_ENV: "value"
EOF

# PersistentVolumeClaim YAML
cat > "$DIR/persistent-volume-claim.yaml" <<EOF
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: ${SERVICE}-data-pvc
  namespace: $SERVICE
spec:
  accessModes:
    - ReadWriteOnce
  storageClassName: nfs-client
  resources:
    requests:
      storage: 1Gi
EOF

# Deployment YAML
cat > "$DIR/deployment.yaml" <<EOF
apiVersion: apps/v1
kind: Deployment
metadata:
  name: ${SERVICE}-deployment
  namespace: $SERVICE
spec:
  replicas: 1
  selector:
    matchLabels:
      app: $SERVICE
  template:
    metadata:
      labels:
        app: $SERVICE
    spec:
      containers:
        - name: $SERVICE
          image: $SERVICE:latest
          resources:
            requests:
              cpu: "100m"
              memory: "128Mi"
            limits:
              cpu: "250m"
              memory: "256Mi"
          ports:
            - containerPort: 80
          envFrom:./
            - configMapRef:
                name: ${SERVICE}-config
            - secretRef:
                name: ${SERVICE}-secret
          volumeMounts:
            - name: ${SERVICE}-data
              mountPath: /data
      volumes:
        - name: ${SERVICE}-data
          persistentVolumeClaim:
            claimName: ${SERVICE}-data-pvc
EOF

# Service YAML
cat > "$DIR/service.yaml" <<EOF
apiVersion: v1
kind: Service
metadata:
  name: ${SERVICE}-service
  namespace: $SERVICE
spec:
  selector:
    app: $SERVICE
  ports:
    - port: 80
      targetPort: 80
EOF

# IngressRoute YAML
cat > "$DIR/ingressroute.yaml" <<EOF
apiVersion: traefik.io/v1alpha1
kind: IngressRoute
metadata:
  name: ${SERVICE}-https-ingress
  namespace: $SERVICE
spec:
  entryPoints:
    - websecure
  routes:
    - match: Host(\`${SERVICE}.slux-solutions.com\`)
      kind: Rule
      services:
        - name: ${SERVICE}-service
          port: 80
  tls:
    secretName: slux-solutions-wildcard-cert
---
apiVersion: traefik.io/v1alpha1
kind: IngressRoute
metadata:
  name: ${SERVICE}-http-ingress
  namespace: $SERVICE
spec:
  entryPoints:
    - web
  routes:
    - match: Host(\`${SERVICE}.slux-solutions.com\`)
      kind: Rule
      middlewares:
        - name: https-redirect
          namespace: $SERVICE
      services:
        - name: ${SERVICE}-service
          port: 80
EOF

cat > "$DIR/kustomization.yaml" <<EOF
resources:
  - bwsecret.yaml
  - namespace.yaml
  - configmap.yaml
  - persistent-volume-claim.yaml
  - deployment.yaml
  - service.yaml
  - ingressroute.yaml
EOF

echo "Created $DIR with basic YAML files."