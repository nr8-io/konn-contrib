local k = import 'konn/main.libsonnet';

// simplified ApisixRoute configuration for basic HTTP routing, without upstreams or plugins
k.feature([
  import './manifests/volumes.libsonnet',
], {
  volumes: {
  },
  features: {
    volumeMounts: true,
  },
}, [
  // use volume mount extension to apply mounts from volume configuration
  function(ctx, props) if k.get(props, 'features.volumeMounts', false) then
    (import '../volume-mounts/extensions/volume-mounts.libsonnet').apply({
      // collect mounts from volume configuration to use in the volume mount extension
      mounts: {
        [volume.key]: volume.value.mounts
        for volume in std.objectKeysValues(props.volumes)
        if std.objectHas(volume.value, 'mounts')
      },
    }),
])
