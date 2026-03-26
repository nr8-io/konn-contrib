local withAffinityMixin = import '../mixins/with-affinity.libsonnet';
local k = import 'konn/main.libsonnet';

k.extension(
  // only apply this extension if there is an affinity configs matching this resource name
  function(ctx, config, props) config + k.onlyIfHas(props.affinity, config.metadata.name, (
    withAffinityMixin(props.affinity[config.metadata.name])
  )),
  {
    affinity: {},
  },
  selector=function(ctx, config, props) (
    local names = std.objectFields(props.affinity);

    config.is('Deployment', names) || config.is('StatefulSet', names) || config.is('DaemonSet', names)
  ),
)
