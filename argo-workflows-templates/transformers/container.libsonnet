// extends Container https://argo-workflows.readthedocs.io/en/latest/fields/#container
function(spec) (
  local overrides = if std.isObject(spec) then spec else {};

  // defaults
  {
    image: 'eu.gcr.io/topvine-co/kubectl:1.35-alpine',
    command: ['/bin/sh', '-c'],
  }

  // apply any additional overrides
  + overrides
)
