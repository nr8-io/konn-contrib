local k = import 'konn/main.libsonnet';

// simplified ApisixRoute configuration for basic HTTP routing, without upstreams or plugins
k.feature([
  import './manifests/apisix-routes.libsonnet',
], {
  routes: {},
})
