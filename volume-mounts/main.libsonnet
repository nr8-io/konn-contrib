local k = import 'konn/main.libsonnet';

// this feature doesn't render any resources itself, but provides volume mount extension
k.feature([
  // nothing
], {
  mounts: {},
}, extensions=[
  function(ctx, props) (import './extensions/volume-mounts.libsonnet').apply({
    mounts: props.mounts,
  }),
])
