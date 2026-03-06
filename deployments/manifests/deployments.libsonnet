local k = import 'konn/main.libsonnet';
local k8s = (import 'k8s-libsonnet/1.35/main.libsonnet');
local util = import '../../util/main.libsonnet';
local container = k8s.core.v1.container;

// parse key:value into env name and key for secrets and config maps, e.g. "secretName:secretKey" or "configMapName:configKey"
local parseEnvValue = function(value) (
  if std.isString(value) then (
    // support simplified "secret" format as "secretName:secretKey"
    local parts = std.split(value, ':');

    {
      name: parts[0],
      key: parts[0],
    }
    // add optional key if provided in "secret:key" format
    + k.onlyIf(std.length(parts) > 1, {
      key: parts[1],
    })
  ) else (
    value
  )
);

// simplified env config with short keys and key:value syntax for secrets and config maps
local parseEnv = function(value) (
  if std.isObject(value) && util.objectHasOneOf(value, ['secret']) then (
    {
      secretKeyRef: parseEnvValue(value.secret),
    }
  )
  else if std.isObject(value) && util.objectHasOneOf(value, ['cm', 'config', 'configmap', 'configMap']) then (
    {
      configMapKeyRef: parseEnvValue(
        util.getFirstNonNull(value, ['cm', 'config', 'configmap', 'configMap'])
      ),
    }
  )
  else (
    value
  )
);

//
k.manifest(function(ctx, props) [
  k8s.apps.v1.deployment.new(
    name=config.key,
    replicas=k.get(config.value, 'replicas', 1),
    containers=[
      container.new(
        name=item.key,
        image=k.get(item.value, 'image', 'busybox'),
      ) + {
        imagePullPolicy: 'IfNotPresent',
      }

      // parse env config with support for simplified syntax for secrets and config maps
      + k.onlyIfHas(item.value, 'env', container.withEnvMap(
        {
          [env.key]: parseEnv(env.value)
          for env in std.objectKeysValues(item.value.env)
        }
      ))
      for item in std.objectKeysValues(config.value.containers)
    ]
  )
  for config in std.objectKeysValues(props.deployments)
], {
  deployments: {},
})
