local k = import 'konn/main.libsonnet';

k.feature([
  import './manifests/cert-manager-certificates.libsonnet',
], {
  certificates: {},
})
