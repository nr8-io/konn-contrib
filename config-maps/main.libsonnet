local k = import 'konn/main.libsonnet';
local k8s = (import 'k8s-libsonnet/1.35/main.libsonnet');

//
k.feature([
  import './manifests/configs-maps.libsonnet',
], {
  data: {},
  values: {},
})
