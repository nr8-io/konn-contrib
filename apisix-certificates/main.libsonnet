local k = import 'konn/main.libsonnet';

k.feature([
  import './manifests/apisix-tls-certificates.libsonnet',

  function(ctx, props) if k.get(props, 'features.certificates', false) then
    (import '../certificates/manifests/certificates.libsonnet'),
], {
  certificates: {},
  features: {
    certificates: true,
  },
})
