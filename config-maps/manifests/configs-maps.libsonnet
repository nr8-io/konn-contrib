local k = import 'konn/main.libsonnet';
local k8s = (import 'k8s-libsonnet/1.35/main.libsonnet');

//
k.manifest(function(ctx, props) [
  k8s.core.v1.configMap.new(
    name=config.key,
    data={
      local values = k.get(props.values, '.[' + config.key + '][' + item.key + ']'),
      [item.key]: if std.isObject(values) then k.template(item.value, values) else item.value
      for item in std.objectKeysValues(config.value)
    }
  )
  for config in std.objectKeysValues(props.data)
], {
  data: {},
  values: {},
})
