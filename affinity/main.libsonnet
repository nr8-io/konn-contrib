local k = import 'konn/main.libsonnet';

// this feature doesn't render any resources itself, but provides affinity extension
k.feature([
  // nothing
], {
  affinity: {},
}, extensions=[
  function(ctx, props) (import './extensions/affinity.libsonnet').apply({
    affinity: props.affinity,
  }),
])
