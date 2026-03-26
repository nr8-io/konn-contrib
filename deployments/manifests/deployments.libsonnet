local k = import 'konn/main.libsonnet';
local k8s = (import 'k8s-libsonnet/1.35/main.libsonnet');
local util = import '../../util/main.libsonnet';
local withAffinityMixin = import '../../affinity/mixins/with-affinity.libsonnet';
local withVolumeMountsMixin = import '../../volume-mounts/mixins/with-volume-mounts.libsonnet';
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
    std.toString(value)
  )
);

//
k.manifest(function(ctx, props) [
  k8s.apps.v1.deployment.new(
    name=config.key,
    replicas=k.get(config.value, 'replicas', 1),
    containers=[
      // container defaults
      container.new(
        name=item.key,
        image=k.get(item.value, 'image', 'busybox'),
      ) + {
        // change default image pull policy to IfNotPresent to avoid unnecessary pulls instead of Always which is the default in Kubernetes
        imagePullPolicy: k.get(item.value, 'imagePullPolicy', 'IfNotPresent'),
      }

      // parse env config with support for simplified syntax for secrets and config maps
      + k.onlyIfHas(item.value, 'env', container.withEnvMap({
        [env.key]: parseEnv(env.value)
        for env in std.objectKeysValues(item.value.env)
      }))

      // apply other container properties, excluding properties which are handled separately with special parsing logic
      + {
        [item.key]: item.value
        for item in std.objectKeysValues(item.value)
        if !std.contains(['env'], item.key)
      }

      // add containers for each key provided
      for item in std.objectKeysValues(config.value.containers)
    ]
  )

  + k.onlyIfHas(config.value, 'affinity', withAffinityMixin(config.value.affinity))
  + k.onlyIfHas(config.value, 'volumes', withVolumeMountsMixin(config.value.volumes))
  for config in std.objectKeysValues(props.deployments)
], {
  deployments: {},
})
