// extends ScriptTemplate https://argo-workflows.readthedocs.io/en/latest/fields/#scripttemplate
function(spec) (
  // script as string
  local overrides = if std.isString(spec.script) then
    {
      script+: {
        source: spec.script,
      },
    }
  else if std.isObject(spec) then
    {
      script+: spec.script,
    }
  else {};

  // defaults
  {
    script: {
      image: 'eu.gcr.io/topvine-co/kubectl:1.35-alpine',
      command: ['/bin/sh'],
      source: 'echo "Hello World"',
      // supply outputs mount by default
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
