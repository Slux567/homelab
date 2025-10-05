from kubernetes import client, config

# Load kubeconfig (use in-cluster config if running inside a pod)
config.load_kube_config()

v1 = client.CoreV1Api()

SOURCE_NS = "bitwarden"
SECRET_NAME = "bw-auth-token"

# Get the source Secret
source = v1.read_namespaced_secret(SECRET_NAME, SOURCE_NS)

# List all namespaces
for ns in v1.list_namespace().items:
    ns_name = ns.metadata.name
    if ns_name == SOURCE_NS:
        continue  # skip the source namespace

    secret = client.V1Secret(
        metadata=client.V1ObjectMeta(name=SECRET_NAME),
        data=source.data,
        type="Opaque"
    )

    try:
        v1.create_namespaced_secret(ns_name, secret)
        print(f"Created secret in {ns_name}")
    except client.exceptions.ApiException as e:
        if e.status == 409:  # already exists
            v1.replace_namespaced_secret(SECRET_NAME, ns_name, secret)
            print(f"Replaced secret in {ns_name}")
        else:
            print(f"Error in {ns_name}: {e}")