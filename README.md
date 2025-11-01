# OpenShift 4.14.x High Availability (HA) UPI Installation Guide

This guide provides a complete **step-by-step runbook** for deploying a **High Availability OpenShift 4.14.x cluster** using the **User-Provisioned Infrastructure (UPI)** method on **bare metal servers** with **HAProxy** as the load balancer.

---

## 1. Overview

### Cluster Topology
| Role | Quantity | Example Hostnames | Example IPs |
|------|-----------|------------------|--------------|
| Bootstrap | 1 | `bootstrap.test.ocp.com` | `192.168.65.9` |
| Masters | 3 | `cp-1.test.ocp.com`, `cp-2.test.ocp.com`, `cp-3.test.ocp.com` | `192.168.65.10-12` |
| Workers | 2 | `w-1.test.ocp.com`, `w-2.test.ocp.com` | `192.168.65.20-21` |
| Load Balancer | 1 | `lb.test.ocp.com` | `192.168.65.2` |
| DNS Server | 1 | `dns.test.ocp.com` | `192.168.65.128` |

---

## 2. Prerequisites

### 2.1 Software
- `openshift-install` (v4.14.x)
- `oc` CLI tools
- `httpd` (for hosting ignition files)
- `coreos-installer`
- `haproxy`

### 2.2 Files
- Pull secret from [Red Hat Cloud Console](https://console.redhat.com/openshift/install)
- SSH key pair (`id_rsa` and `id_rsa.pub`)

### 2.3 Network
| Record | Type | Target |
|---------|------|---------|
| `api.test.ocp.com` | A | `192.168.65.2` |
| `api-int.test.ocp.com` | A | `192.168.65.2` |
| `*.apps.test.ocp.com` | A | `192.168.65.2` |

### 2.4 Firewall / Ports
Ensure the following ports are open between nodes:
- 6443/tcp — API Server
- 22623/tcp — Machine Config Server
- 443, 80/tcp — Router / Apps

---

## 3. Prepare Installation Directory
```bash
mkdir -p ~/ocp-install
cd ~/ocp-install
cp ~/pull-secret.json .
cp ~/.ssh/id_rsa.pub .
```

---

## 4. Create `install-config.yaml`
```yaml
apiVersion: v1
baseDomain: test.ocp.com
metadata:
  name: test
platform:
  none: {}
pullSecret: '<PASTE_PULL_SECRET_JSON>'
sshKey: '<PASTE_SSH_PUB_KEY>'
controlPlane:
  name: master
  replicas: 3
compute:
- name: worker
  replicas: 2
networking:
  networkType: OpenShiftSDN
  clusterNetwork:
  - cidr: 10.128.0.0/14
    hostPrefix: 23
  serviceNetwork:
  - 172.30.0.0/16
fips: false
```

---

## 5. Generate Ignition Files
```bash
openshift-install create manifests --dir=.
openshift-install create ignition-configs --dir=.
ls -l *.ign
```
You should see `bootstrap.ign`, `master.ign`, and `worker.ign`.

---

## 6. Configure HTTP Server
```bash
sudo dnf install -y httpd
sudo mkdir -p /var/www/html/ignitions
sudo cp ~/ocp-install/*.ign /var/www/html/ignitions/
sudo systemctl enable --now httpd
sudo firewall-cmd --add-service=http --permanent
sudo firewall-cmd --reload
```
Validate:
```bash
curl http://192.168.65.128/ignitions/bootstrap.ign
```

---

## 7. Configure HAProxy (Load Balancer)
Edit `/etc/haproxy/haproxy.cfg`:
```cfg
frontend api_frontend
  bind *:6443
  mode tcp
  default_backend api_backend

backend api_backend
  mode tcp
  balance roundrobin
  server cp-1 192.168.65.10:6443 check
  server cp-2 192.168.65.11:6443 check
  server cp-3 192.168.65.12:6443 check

frontend apps_frontend
  bind *:80
  bind *:443
  mode tcp
  default_backend apps_backend

backend apps_backend
  mode tcp
  balance roundrobin
  server cp-1 192.168.65.10:443 check
  server cp-2 192.168.65.11:443 check
  server cp-3 192.168.65.12:443 check
```
Enable and verify:
```bash
sudo systemctl enable --now haproxy
ss -tnlp | grep haproxy
```

---

## 8. Install RHCOS Nodes (CoreOS Installer)

### Bootstrap
```bash
sudo coreos-installer install --insecure --ignition-url http://192.168.65.128/ignitions/bootstrap.ign /dev/sda
sudo reboot
```

### Masters
Repeat for each master node:
```bash
sudo coreos-installer install --insecure --ignition-url http://192.168.65.128/ignitions/master.ign /dev/sda
sudo reboot
```

### Workers
Repeat for each worker node:
```bash
sudo coreos-installer install --insecure --ignition-url http://192.168.65.128/ignitions/worker.ign /dev/sda
sudo reboot
```

---

## 9. Start Installation
On the admin host:
```bash
openshift-install create cluster --dir=~/ocp-install --log-level=info
```
Monitor logs:
```bash
tail -f ~/ocp-install/.openshift_install.log
```

---

## 10. Monitor Bootstrap Progress
```bash
openshift-install wait-for bootstrap-complete --dir=~/ocp-install --log-level=debug
```
Once complete, remove the bootstrap server from HAProxy.

---

## 11. Configure Cluster Access
```bash
export KUBECONFIG=~/ocp-install/auth/kubeconfig
oc get nodes
```
Approve pending CSRs:
```bash
oc get csr
for csr in $(oc get csr --no-headers | awk '{print $1}'); do oc adm certificate approve $csr; done
```

---

## 12. Wait for Cluster Operators
```bash
oc get co
```
All operators should report:
- `AVAILABLE=True`
- `PROGRESSING=False`
- `DEGRADED=False`

---

## 13. Verify Installation
```bash
oc get nodes -o wide
oc get pods -A | egrep -v 'Running|Completed'
oc get clusterversion
```

---

## 14. Next Steps
After successful installation:
- Configure **image registry storage** (NFS or PVC)
- Apply **custom self-signed TLS certificates**
- Create **admin/developer users** via HTPasswd

Those post-install tasks are covered in a separate guide: [README-postinstall.md](README-postinstall.md)

---

## 15. Cleanup and Maintenance
- Remove bootstrap VM after success.
- Backup `install-dir/auth/kubeconfig` securely.
- Regularly verify operator and node health.

---

## 16. References
- [OpenShift Documentation: Installing on Bare Metal (UPI)](https://docs.openshift.com/container-platform/latest/installing/installing_bare_metal/installing-bare-metal.html)
- [Red Hat Knowledgebase](https://access.redhat.com/documentation/en-us/openshift_container_platform/)

---

**End of Installation README.md**

