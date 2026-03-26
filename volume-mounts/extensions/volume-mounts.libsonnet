local withVolumeMountsMixin = import '../mixins/with-volume-mounts.libsonnet';
local k = import 'konn/main.libsonnet';

// automatically add volume mounts to containers based on a selector syntax in the volume definition, e.g. "silverstripe/[nginx, php]" would add the volume to the nginx and php containers in the silverstripe deployment
k.extension(
  function(ctx, config, props) config + k.onlyIfHas(props, 'mounts', (
    withVolumeMountsMixin(props.mounts, config.metadata.name)
  )),
  {
    mounts: {},
  },
  selector=function(ctx, config, props) (
    // @TODO filter names based on selectors
    config.is('Deployment') || config.is('StatefulSet') || config.is('DaemonSet')
  ),
)
