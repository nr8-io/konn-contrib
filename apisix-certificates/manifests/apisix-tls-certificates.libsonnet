local k = import 'konn/main.libsonnet';

k.manifest(function(ctx, props) [
  {
    apiVersion: 'apisix.apache.org/v2',
    kind: 'ApisixTls',
    metadata: {
      name: cert.key,
    } + k.onlyIfHas(cert.value, 'namespace', {
      namespace: cert.value.namespace,
    }),
    spec: {
      hosts:
        []
        + k.onlyIfHas(cert.value, 'host', [cert.value.host], [])
        + k.onlyIfHas(cert.value, 'hosts', cert.value.hosts, []),
      secret: {
        name: cert.key + '-tls',
      } + k.onlyIfHas(cert.value, 'namespace', {
        namespace: cert.value.namespace,
      }),
    },
  }
  for cert in std.objectKeysValues(props.certificates)
], {
  certificates: {},
})
