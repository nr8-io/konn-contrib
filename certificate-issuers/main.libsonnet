local k = import 'konn/main.libsonnet';

k.feature([
  import './manifests/issuers.libsonnet',
], {
  issuers: {},
})
