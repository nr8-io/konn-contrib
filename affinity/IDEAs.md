## IDEA backfill with super operator

We want to provide simple config as a key:value object, eg. for
labels because for 99% of use cases it is the simplest, however we want to
adjust something like the weight, we can't do a simple object check because
it breaks the functionality of key:value because maybe we have a selector like
"expression=enabled" that we want to add to affinity it breaks compat.

eg.
```yaml
affinity:
  cloudbeaver:
    node:
      prefer:
        - expressions:
            node.topvine.co/workload.application.tool: "true"
          weight: 20
        - expressions: "enabled"
        - node.topvine.co/workload.database.mssql: "true"
```

We cant test for the key "expressions" because it might be a valid value for a
label, this is 100% why the original spec is written the way it is but our goal
is to do the 90% use case with exceptions for the rest rather than solve the
problem which is already solved by the original spec.

current solution uses special keys which are filtered by default to provide
values to the parent object, this works reasonably well and doesn't look
horrible but it is applied very specifically in this plugin and could possibly
be more generic so we can apply it as a general rule for kontrib libs

If we take something out of the jsonnet play book and treat "$" as super then we
can apply a rule that says $ is pinned to a specific parent in the original tree
in this case pod.prefer = podAffinity.preferredDuringSchedulingIgnoredDuringExecution[].item
where $ is referenced to the parent item so key:value is used in
`$.matchExpressions` since this is our target shortcut for the 90% use case

For the sake of this example it could be nested even deeper so we say $ is bound
to preferredDuringSchedulingIgnoredDuringExecution[].item so using $ inside
of the prefer.item would refer to a pinned parent making $.wight: 20 a valid
value, but also $.matchExpressions etc

This comes back to an idea I had in passing about making $: the key for applying
generic patches to parent objects and would be easier to apply as a general
rule when writing kontrib style plugins for existing schemas

```yaml
affinity:
  cloudbeaver:
    node:
      prefer:
        - $.weight: 20
          node.topvine.co/workload.application.tool: "true"
        - $.weight: 50
          node.topvine.co/workload.database: "true"
        - $.weight: 100
          node.topvine.co/workload.database.mssql: "true"
```

I think overall this keeps the best of both worlds, it allows for the short
simple config skipping some depth where a simple object/array check would
conflict but still allowing for patching parent values for the 10% case like.

I've never seen $ used anywhere else so its easy to filter out and if added
at the start of an object has a "config" type feel for setting values, making
use of dot notation keeps it flat for simple cases or can be provided as a full
patch

This is still reasonably uncommon as well where we want to skip config depth
that can't be figured out by simple type checks