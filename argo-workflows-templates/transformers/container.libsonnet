// extends Container https://argo-workflows.readthedocs.io/en/latest/fields/#container
function(spec) (
  local overrides = if std.isObject(spec) then
    {
      container+: spec.container,
    }
  else {};

  // defaults
  {
    container: {
      image: 'eu.gcr.io/topvine-co/kubectl:1.35-alpine',
      command: ['/bin/sh', '-c'],
      volumeMounts: [{
        name: 'outputs',
        mountPath: '/mnt/outputs',
      }],
    },
    volumes: [{
      name: 'outputs',
      emptyDir: {},
    }],
  }

  // apply any additional overrides
  + overrides
)
