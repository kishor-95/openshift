$TTL 1W
@       IN  SOA     ns1.ocp.com. root (
            2025100101        ; Serial
            3H   ; Refresh
            30M    ; Retry
            2W  ; Expire
            1W ) ; Minimum

        IN  NS  ns1.ocp.com.

ns1.ocp.com.             IN  A   192.168.65.128
admin.ocp.com	         IN  A   192.168.65.128

; Bootstrap node
bootstrap.test.ocp.com.  IN  A   192.168.65.9

; Control plane nodes
cp-1.test.ocp.com.   IN  A   192.168.65.10
;cp-2.test.ocp.com.   IN  A   192.168.65.11
;cp-3.test.ocp.com.   IN  A   192.168.65.12

; Worker nodes
w-1.test.ocp.com.    IN  A   192.168.65.20

; Load balancer
api.test.ocp.com.        IN  A   192.168.65.128
api-int.test.ocp.com.    IN  A   192.168.65.128
*.apps.test.ocp.com.     IN  A   192.168.65.128

; ETCD nodes
etcd-1.test.ocp.com.     IN  A   192.168.65.10
;etcd-2.test.ocp.com.     IN  A   192.168.65.11
;etcd-3.test.ocp.com.     IN  A   192.168.65.12

; SRV records
_etcd-server-ssl._tcp.test.ocp.com. 86400 IN SRV 0 10 2380 etcd-1.test.ocp.com.
;_etcd-server-ssl._tcp.test.ocp.com. 86400 IN SRV 0 10 2380 etcd-2.test.ocp.com.
;_etcd-server-ssl._tcp.test.ocp.com. 86400 IN SRV 0 10 2380 etcd-3.test.ocp.com.

; Misc
oauth-openshift.apps.test.ocp.com.           IN A 192.168.65.128
console-openshift-console.apps.test.ocp.com. IN A 192.168.65.128

