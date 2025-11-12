• Scenario A – External LB + Ingress (full L7 stack)

                   ┌─────────────────────┐
                   │   Internet Client   │
                   └─────────┬───────────┘
                             │
                 ┌───────────▼───────────┐
                 │ Global/External LB    │
                 │ (Anycast, WAF, BGP)   │
                 └───────────┬───────────┘
                             │  private VIP / routed path
             ┌───────────────▼────────────────┐
             │ Kubernetes Edge Node           │
             │ ┌────────────────────────────┐ │
             │ │ Calico: routing + NetPol   │ │
             │ │ kube-proxy: Service L4 LB  │ │
             │ └────────────────────────────┘ │
             └───────────────┬────────────────┘
                             │  ClusterIP traffic
                  ┌──────────▼───────────┐
                  │ Ingress Controller   │
                  │ (NGINX / Envoy /     │
                  │  Istio Gateway)      │
                  │ - TLS termination    │
                  │   (cert-manager)     │
                  │ - host/path routing  │
                  │ - auth, WAF, logs    │
                  └──────────┬───────────┘
                             │ forwards to Service
                ┌────────────▼────────────┐
                │ Service (ClusterIP)     │
                │ + optional mesh virtual │
                └────────────┬────────────┘
                             │ Pod endpoint
             ┌───────────────▼────────────────┐
             │ Application Pod(s)             │
             │ (optional mesh sidecars, mTLS) │
             └────────────────────────────────┘

  Scenario B – External LB directly to Service type LoadBalancer (pure L4)

                   ┌─────────────────────┐
                   │   Internet Client   │
                   └─────────┬───────────┘
                             │
                 ┌───────────▼───────────┐
                 │ Global/External LB    │
                 │ (IP for Service)      │
                 └───────────┬───────────┘
                             │  LoadBalancer IP via MetalLB/BGP
             ┌───────────────▼────────────────┐
             │ Kubernetes Node(s)             │
             │ ┌────────────────────────────┐ │
             │ │ Calico: routing + NetPol   │ │
             │ │ kube-proxy: L4 translation │ │
             │ └────────────────────────────┘ │
             └───────────────┬────────────────┘
                             │  Service type LoadBalancer
                ┌────────────▼────────────┐
                │ Service (LoadBalancer)  │
                │ (one IP per workload)   │
                └────────────┬────────────┘
                             │ Pod endpoint
             ┌───────────────▼────────────────┐
             │ Application Pod(s)             │
             │ (app handles TLS if needed)    │
             └────────────────────────────────┘

• W dużych firmach dorzuca się zwykle dwa kolejne elementy: service mesh (np. Istio/Linkerd) oraz dataplane oparte o eBPF (Calico eBPF, Cilium). To zmienia warstwy, ale nie usuwa żadnej z poprzednich funkcji. Poniżej warianty „ładnych”
  diagramów uwzględniające te dodatki.

  Scenario A – External LB + Ingress + Service Mesh + eBPF dataplane

                   ┌─────────────────────┐
                   │   Internet Client   │
                   └─────────┬───────────┘
                             │
                 ┌───────────▼───────────┐
                 │ Global/External LB    │
                 │ (Anycast, WAF, BGP)   │
                 └───────────┬───────────┘
                             │  private VIP / routed path
            ┌────────────────▼─────────────────┐
            │ Kubernetes Edge Node             │
            │ ┌──────────────────────────────┐ │
            │ │ eBPF dataplane (Calico/Cilium)││
            │ │  - routing + NetworkPolicy    ││
            │ │  - replaces kube-proxy rules  ││
            │ │    with kernel-level programs ││
            │ └──────────────────────────────┘ │
            └────────────────┬─────────────────┘
                             │  ClusterIP traffic
                  ┌──────────▼───────────┐
                  │ Ingress Gateway      │
                  │ (Envoy/Istio Gateway)│
                  │ - TLS termination    │
                  │   (cert-manager)     │
                  │ - host/path routing  │
                  │ - auth, WAF, filters │
                  └──────────┬───────────┘
                             │ into mesh
                ┌────────────▼────────────┐
                │ Service Mesh Control    │
                │ Plane (Istio Pilot, etc)│
                └────────────┬────────────┘
                             │ config xDS
             ┌───────────────▼────────────────┐
             │ Workload Pod(s) + Sidecar      │
             │ ┌────────────────────────────┐ │
             │ │ Envoy/Linkerd proxy (sidecar)││
             │ │ - mTLS east-west            ││
             │ │ - retries, canary, policies ││
             │ └────────────────────────────┘ │
             │ Application container          │
             └────────────────────────────────┘

  W tym układzie:

  - eBPF dataplane (Calico/Cilium) obsługuje routing i load balancing w jądrze, więc kube-proxy bywa wyłączony lub działa w trybie „stub”.
  - Service mesh przejmuje kontrolę nad ruchem w klastrze (mTLS, telemetry, canary), a ingress gateway jest elementem mesh-a.

  Scenario B – External LB → Service type LoadBalancer + Service Mesh + eBPF

                   ┌─────────────────────┐
                   │   Internet Client   │
                   └─────────┬───────────┘
                             │
                 ┌───────────▼───────────┐
                 │ Global/External LB    │
                 │ (IP per workload)     │
                 └───────────┬───────────┘
                             │  LB IP via MetalLB/BGP
            ┌────────────────▼─────────────────┐
            │ Kubernetes Node(s)               │
            │ ┌──────────────────────────────┐ │
            │ │ eBPF dataplane (Calico/Cilium)││
            │ │  - Handles Service LB/NodePort││
            │ │  - Enforces NetworkPolicy     ││
            │ └──────────────────────────────┘ │
            └────────────────┬─────────────────┘
                             │  Service type LoadBalancer
                ┌────────────▼────────────┐
                │ Service (LoadBalancer)  │
                │ - Pod endpoints tracked │
                └────────────┬────────────┘
                             │
             ┌───────────────▼────────────────┐
             │ Workload Pod(s) + Sidecar      │
             │ ┌────────────────────────────┐ │
             │ │ Mesh proxy (sidecar)       │ │
             │ │ - mTLS, rate limit, A/B    │ │
             │ │ - L7 telemetry             │ │
             │ └────────────────────────────┘ │
             │ Application container          │
             └────────────────────────────────┘

  Najważniejsze zmiany względem „prostych” scenariuszy:

  - eBPF dataplane – zamiast iptables kube-proxy masz programy eBPF instalowane w jądrze (Calico eBPF, Cilium). Zapewniają niższe opóźnienia, mniejsze zużycie CPU i lepsze monitorowanie. Kube-proxy staje się opcjonalny lub pracuje tylko
    jako watcher CRD.
  - Service mesh – każdy pod dostaje sidecar proxy. Ingress często jest gateway’em tej samej platformy, więc ruch po terminacji TLS od razu trafia do mesh (z mTLS east-west, politykami bezpieczeństwa, routingiem L7).
  - Kontrola ruchu – mesh pozwala sterować requestami (retry, timeout, mirroring, canary) niezależnie od aplikacji. eBPF daje wgląd w pakiety i metrics bez dodatkowych agentów.

  Dzięki temu „big tech” może mieć globalny LB + mesh + eBPF: warstwa zewnętrzna dba o HA, mesh o logikę aplikacyjną, a dataplane eBPF trzyma wydajność i bezpieczeństwo na poziomie jądra.
