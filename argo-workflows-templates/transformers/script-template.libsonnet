// extends ScriptTemplate https://argo-workflows.readthedocs.io/en/latest/fields/#scripttemplate
function(spec) (
  // script as string
  local overrides = if std.isString(spec) then
    {
      source: spec,
    }
  else if std.isObject(spec) then spec
  else {};

  // defaults
  {
    image: 'eu.gcr.io/topvine-co/kubectl:1.35-alpine',
    command: ['/bin/sh'],
    source: 'echo "Hello World"',
  }

  // apply any additional overrides
  + overrides
)
