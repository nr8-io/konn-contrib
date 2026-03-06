local k = import 'konn/main.libsonnet';

k.manifest(function(ctx, props) [
  {
    apiVersion: 'v1',
    kind: 'PersistentVolumeClaim',
    metadata: {
      name: volume.key,
    } + k.onlyIfHas(volume.value, 'namespace', {
      namespace: volume.value.namespace,
    }),
    spec:
      {
        accessModes: ['ReadWriteOnce'],
        resources: {
          requests: {
            storage: k.get(volume.value, 'storage', '1Gi'),
          },
        },
      }
      + k.onlyIfHas(volume.value, 'type', {
        storageClassName: volume.value.type,
      })
      + k.onlyIfHas(volume.value, 'accessMode', {
        accessModes: [volume.value.access],
      })
      + k.onlyIfHas(volume.value, 'accessModes', {
        accessModes: volume.value.accessModes,
      }),
  }
  for volume in std.objectKeysValues(props.volumes)
], {
  volumes: {},
})
