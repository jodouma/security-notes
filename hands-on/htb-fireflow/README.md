# HTB Fireflow - Langflow, MCP, and Kubernetes Lab

> Authorized Hack The Box lab notes. All values that are credentials, bearer
> tokens, callback addresses, or flags are intentionally redacted.

This completed Medium Linux machine demonstrates how independent trust failures
can be chained into host-root impact:

1. A leaked public Langflow flow UUID plus CVE-2026-33017 permits unauthenticated code execution.
2. A Langflow environment password is reused by a local SSH user.
3. A custom MCP registry accepts unsigned JWTs when the client sets `alg: none`.
4. Admin-only custom-tool registration runs submitted Python in an MCP pod.
5. The pod ServiceAccount has `get` on `nodes/proxy`.
6. A direct Kubelet WebSocket `GET` is authorized as `get nodes/proxy`, allowing execution in a privileged node-exporter pod that exposes the host root filesystem.

## Files

- `fireflow-htb-walkthrough.pdf` - command-by-command narrative, rationale, checkpoints, failed attempts, a six-stage capability chain, trust-boundary map, direct-Kubelet request sequence diagram, and a chapter-by-chapter "You are here / Next" escalation rail.
- `scripts/mcp_auth_enum.sh` - authenticate to the lab MCP endpoint and record non-secret JWT metadata.
- `scripts/mcp_admin_callback.sh` - lab-only proof of top-level custom-tool execution.
- `scripts/mcp_k8s_root_v2.sh` - lab-only one-shot direct-Kubelet reader. It demonstrates the correct distinction between API-server proxy requests and a direct Kubelet WebSocket handshake.

## Main technical lesson

`get nodes/proxy` is not safely read-only. Kubelet endpoints including `/exec`
support WebSockets. A WebSocket begins with HTTP `GET`; if a Kubelet maps that
handshake to the `get` authorization verb, a ServiceAccount with only
`get nodes/proxy` can execute commands in pods on reachable nodes.

For Fireflow, the successful request is direct to the node Kubelet rather than
through `kubernetes.default.svc`:

```text
wss://<NODE_IP>:10250/exec/<namespace>/<pod>/<container>
  ?output=1&error=1&command=/bin/sh&command=-c&command=<command>
```

It uses the ServiceAccount bearer token and `v4.channel.k8s.io` protocol. A
normal POST to the API-server proxy is correctly denied because it requires
`create nodes/proxy`; that denial is a useful diagnostic, not a dead end.

## Defensive takeaways

- Update Langflow and prevent unauthenticated public-flow build requests from accepting client-provided flow definitions.
- Store application credentials in a secrets manager, rotate exposed values, and prohibit password reuse between service and SSH accounts.
- Pin JWT verification to an expected signing algorithm and reject `none`.
- Do not execute arbitrary registered MCP tool code; isolate tools and use a strict allow-list.
- Do not grant `nodes/proxy` to workload ServiceAccounts. Prefer narrow Kubelet metrics/log access and restrict network access to port 10250.
- Treat privileged pods, `hostPID`, `hostNetwork`, and `hostPath: /` as high-impact exceptions requiring explicit review.

## References

- [CVE-2026-33017 / GHSA-vwmf-pq79-vjvx](https://github.com/advisories/GHSA-vwmf-pq79-vjvx)
- [Kubernetes: API Server Bypass Risks](https://kubernetes.io/docs/concepts/security/api-server-bypass-risks/)
- [Kubernetes nodes/proxy WebSocket research](https://grahamhelton.com/blog/nodes-proxy-rce)
