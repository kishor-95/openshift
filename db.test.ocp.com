$TTL 1W
@   IN  SOA dns.test.ocp.com. root.test.ocp.com. (
        2025110401 ; Serial
        3H         ; Refresh
        30M        ; Retry
        2W         ; Expire
        1W )       ; Minimum

        IN  NS  dns.test.ocp.com.
@       IN  A   192.168.1.131
dns     IN  A   192.168.1.131

; Bootstrap node
bootstrap.test.ocp.com.  IN  A   192.168.1.133

; Control plane nodes
cp-1.test.ocp.com.   IN  A   192.168.1.134
;cp-2.test.ocp.com.   IN  A   192.168.1.135
;cp-3.test.ocp.com.   IN  A   192.168.1.136

; Worker nodes
w-1.test.ocp.com.    IN  A   192.168.1.214

; Load balancer / API VIP
api.test.ocp.com.        IN  A   192.168.1.131
api-int.test.ocp.com.    IN  A   192.168.1.131
*.apps.test.ocp.com.     IN  A   192.168.1.131

; ETCD nodes
etcd-1.test.ocp.com.     IN  A   192.168.1.134
;etcd-2.test.ocp.com.     IN  A   192.168.1.135
;etcd-3.test.ocp.com.     IN  A   192.168.1.136

; SRV records for ETCD
_etcd-server-ssl._tcp.test.ocp.com. 86400 IN SRV 0 10 2380 etcd-1.test.ocp.com.
;_etcd-server-ssl._tcp.test.ocp.com. 86400 IN SRV 0 10 2380 etcd-2.test.ocp.com.
;_etcd-server-ssl._tcp.test.ocp.com. 86400 IN SRV 0 10 2380 etcd-3.test.ocp.com.

; Misc
oauth-openshift.apps.test.ocp.com.           IN A 192.168.1.131
console-openshift-console.apps.test.ocp.com. IN A 192.168.1.131
admin.test.ocp.com.                          IN A 192.168.1.131

