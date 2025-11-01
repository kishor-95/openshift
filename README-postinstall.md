# OpenShift 4.14.x Post-Installation Configuration (HA UPI)

This guide covers essential **post-installation configurations** for an **OpenShift 4.14.x High Availability UPI cluster** on bare metal. It includes image registry setup, self-signed TLS configuration, local user creation, and key troubleshooting commands.

---

## 1. Configure Image Registry

By default, the image registry is **Removed** or **Degraded** in UPI installations due to missing storage. Choose one of the following methods.

---

### Option 1 — Temporary Storage (EmptyDir)

> ⚠️ **Volatile:** Data will be lost on pod restarts or node reboots.

```bash
oc patch configs.imageregistry.operator.openshift.io/cluster \
  --type=merge -p '{"spec":{"storage":{"emptyDir":{}},"managementState":"Managed"}}'
```

Verify pod rollout:

```bash
oc get pods -n openshift-image-registry -w
```

---

### Option 2 — Persistent Storage (NFS)

> Recommended for production.

1. **Create PV**

```bash
cat > registry-pv.yaml <<'YAML'
apiVersion: v1
kind: PersistentVolume
metadata:
  name: registry-pv
spec:
  capacity:
    storage: 100Gi
  accessModes:
  - ReadWriteMany
  persistentVolumeReclaimPolicy: Retain
  nfs:
    server: <NFS_SERVER_IP>
    path: /exports/registry
YAML

oc apply -f registry-pv.yaml
```

2. **Create PVC**

```bash
cat > registry-pvc.yaml <<'YAML'
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: image-registry-storage
  namespace: openshift-image-registry
spec:
  accessModes:
  - ReadWriteMany
  resources:
    requests:
      storage: 100Gi
YAML

oc apply -f registry-pvc.yaml
```

3. **Patch the operator**

```bash
oc patch configs.imageregistry.operator.openshift.io/cluster \
  --type=merge -p '{"spec":{"storage":{"pvc":{"claim":"image-registry-storage"}},"managementState":"Managed"}}'
```

4. **Validate**

```bash
oc get pods -n openshift-image-registry
oc get pvc -n openshift-image-registry
```

If PVC or PV are stuck terminating:

```bash
oc patch pvc image-registry-storage -n openshift-image-registry -p '{"metadata":{"finalizers":null}}' --type=merge
oc delete pvc image-registry-storage -n openshift-image-registry --force --grace-period=0
```

---

## 2. Apply Self-Signed TLS Certificate

Replace the default ingress certificate with a **self-signed wildcard cert**.

1. **Generate certificate**

```bash
mkdir -p /tmp/ocp-cert && cd /tmp/ocp-cert
openssl genrsa -out wildcard.key 4096
openssl req -x509 -new -nodes -key wildcard.key -sha256 -days 730 \
  -out wildcard.crt \
  -subj "/CN=*.apps.test.ocp.com/O=Your Name/OU=Platform" \
  -addext "subjectAltName=DNS:*.apps.test.ocp.com,DNS:apps.test.ocp.com"
```

2. **Create secret and patch ingress**

```bash
oc create secret tls custom-router-certs -n openshift-ingress \
  --cert=wildcard.crt --key=wildcard.key

oc patch ingresscontroller default -n openshift-ingress-operator --type=merge \
  -p '{"spec":{"defaultCertificate":{"name":"custom-router-certs"}}}'
```

3. **Verify deployment**

```bash
oc get pods -n openshift-ingress -w
openssl s_client -connect oauth-openshift.apps.test.ocp.com:443 -servername oauth-openshift.apps.test.ocp.com 2>/dev/null | openssl x509 -noout -subject -issuer -dates
```

If using a browser, import `wildcard.crt` into the local trust store to suppress warnings.

---

## 3. Create Local Users (HTPasswd)

### 3.1 Create Password File

```bash
sudo dnf install -y httpd-tools   # or apt-get install apache2-utils
htpasswd -c -B -b users.htpasswd admin AdminPassword123
htpasswd -B -b users.htpasswd developer DevPassword123
```

### 3.2 Create Secret and Apply OAuth Configuration

```bash
oc create secret generic htpass-secret --from-file=htpasswd=users.htpasswd -n openshift-config

cat > oauth-htpasswd.yaml <<'YAML'
apiVersion: config.openshift.io/v1
kind: OAuth
metadata:
  name: cluster
spec:
  identityProviders:
  - name: localusers
    mappingMethod: claim
    type: HTPasswd
    htpasswd:
      fileData:
        name: htpass-secret
YAML

oc apply -f oauth-htpasswd.yaml
```

### 3.3 Assign Roles

```bash
oc adm policy add-cluster-role-to-user cluster-admin admin
oc new-project dev-project
oc adm policy add-role-to-user edit developer -n dev-project
```

### 3.4 Secure Cleanup

```bash
shred -u users.htpasswd
```

---

## 4. Fix Common Post-Install Issues

### 4.1 Insights Operator Error

If you see:

```
Unable to report: unable to build request to connect to Insights server
```

Check connectivity:

```bash
oc run -it --rm curltest --image=registry.access.redhat.com/ubi8/ubi-minimal \
  -- bash -c "microdnf install -y curl ca-certificates; curl -v https://console.redhat.com/api/ingress/v1/upload"
```

If blocked by proxy, update the cluster-wide proxy config:

```bash
oc edit proxy cluster
```

### 4.2 Machine Config Operator (MCO) Degraded

If `master` MCP remains degraded:

```bash
oc get mcp
oc describe mcp master
```

If acceptable (e.g. single-node or manual environment), pause updates:

```bash
oc patch mcp master --type=merge -p '{"spec":{"paused":true}}'
```

---

## 5. Monitoring and Troubleshooting

### 5.1 Common Cluster Checks

```bash
export KUBECONFIG=~/ocp-install/auth/kubeconfig
oc get nodes -o wide
oc get co
oc get pods -A | egrep -v 'Running|Completed'
```

### 5.2 CSR Handling

```bash
oc get csr
for csr in $(oc get csr --no-headers | awk '{print $1}'); do oc adm certificate approve $csr; done
```

### 5.3 Inspect MachineConfig

```bash
oc get mcp
oc describe mcp master
journalctl -u machine-config-daemon -n 100
```

### 5.4 Inspect Networking and Routes

```bash
oc get ingresscontroller -A
oc get routes -A
oc get svc -A | grep router
```

### 5.5 Operator Health

```bash
oc get co | egrep -v 'True +False +False'
oc logs -n openshift-apiserver <pod_name> --tail=100
```

---

## 6. Verification Checklist

* [ ] All **ClusterOperators** show `AVAILABLE=True`
* [ ] All **Nodes** show `Ready`
* [ ] Image registry pods are running
* [ ] OAuth authentication works for both users
* [ ] TLS certificate applied successfully

---

## 7. References

* [OpenShift: Configuring the Registry Operator](https://docs.openshift.com/container-platform/latest/registry/configuring_registry_storage/configuring-registry-storage-baremetal.html)
* [OpenShift: Configuring HTPasswd Authentication](https://docs.openshift.com/container-platform/latest/authentication/identity_providers/configuring-htpasswd-identity-provider.html)
* [OpenShift: Custom Router Certificates](https://docs.openshift.com/container-platform/latest/networking/ingress-operator.html)

---

**End of README-postinstall.md**
