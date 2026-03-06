local k = import 'konn/main.libsonnet';

k.manifest(function(ctx, props) [
  {
    apiVersion: 'cert-manager.io/v1',
    kind: 'Certificate',
    metadata: {
      name: cert.key,
    } + k.onlyIfHas(cert.value, 'namespace', {
      namespace: cert.value.namespace,
    }),
    spec: {
      secretName: cert.key + '-tls',
      issuerRef: {
        name: k.get(cert, 'value.issuer', 'self-signed'),
        kind: k.get(cert, 'value.kind', 'Issuer'),
      },
      dnsNames:
        []
        + k.onlyIfHas(cert.value, 'host', [cert.value.host], [])
        + k.onlyIfHas(cert.value, 'hosts', cert.value.hosts, []),
    },
  }
  for cert in std.objectKeysValues(props.certificates)
], {
  certificates: {},
})
