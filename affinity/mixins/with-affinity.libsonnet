local util = import 'konn-contrib/util/main.libsonnet';
local k = import 'konn/main.libsonnet';

// simplified OR logic for affinity selectors
local getAnyOf = function(val, default={}) (
  if std.isArray(val) then val
  else default
);

// simplified AND logic for affinity selectors
local getAllOf = function(val, default=val) (
  if std.isArray(val) then {}  // anyOf
  else default
);

// simplified affinity operators
local getOperator = function(val) (
  if std.isString(val) then 'In'
  else if std.isArray(val) then 'In'
  else if std.isBoolean(val) then if val then 'Exists' else 'DoesNotExist'
  else if std.objectHas(val, 'operator') then val.operator
  else if std.objectHas(val, 'value') then 'In'
  else if std.objectHas(val, 'values') then 'In'
  else if std.objectHas(val, 'in') then 'In'
  else if std.objectHas(val, 'not') then 'NotIn'
  else if std.objectHas(val, 'exists') && val.exists then 'Exists'
  else if std.objectHas(val, 'exists') && !val.exists then 'DoesNotExist'
  else if std.objectHas(val, 'gt') then 'Gt'
  else if std.objectHas(val, 'lt') then 'Lt'
  else if std.objectHas(val, 'key') && std.length(val) == 1 then 'Exists'
  else if std.isObject(val) && std.length(val) == 0 then 'Exists'
  else 'In'
);

// simplified affinity values
local withValues = function(val) (
  if std.isString(val) then { values: [val] }
  else if std.isArray(val) then { values: val }
  else if std.isBoolean(val) then {}
  else if std.objectHas(val, 'value') then withValues(val.value)
  else if std.objectHas(val, 'values') then withValues(val.values)
  else if std.objectHas(val, 'in') then withValues(val['in'])
  else if std.objectHas(val, 'not') then withValues(val.not)
  else if std.objectHas(val, 'exists') then {}
  else if std.objectHas(val, 'not') then withValues(val.not)
  else if std.objectHas(val, 'gt') then withValues(val.gt)
  else if std.objectHas(val, 'lt') then withValues(val.lt)
  else if std.isObject(val) && std.length(val) == 0 then {}
  else {}
);

local matchExpressions = function(items, key=null) (
  [
    (
      local defaultKey = if key == null then item.key else key;
      local itemKey = k.get(item.value, 'key', defaultKey);
      local value = k.get(item.value, 'value', item.value);

      {
        key: itemKey,
        operator: getOperator(value),
      }
      + withValues(value)
    )
    for item in util.getKeysValues(items)
    if !std.startsWith(item.key, '$')
  ]
);

local podAffinityTerm = function(term, key=null) (
  local labels = k.get(term, '$labels', term);
  local namespaces = k.get(term, '$namespaces', {});

  {
    labelSelector: {
      matchExpressions: matchExpressions(if key == null then labels else { [key]: labels }),
    },
    topologyKey: k.get(term, '$topology', 'kubernetes.io/hostname'),
  }

  // add an optional namespace selector if $namespaces is set
  + k.onlyIf(std.length(namespaces) > 0, {
    namespaceSelector: {
      matchExpressions: matchExpressions(namespaces, if std.isArray(namespaces) then 'kubernetes.io/metadata.name'),
    },
  })

  + k.onlyIfHas(term, '$matchLabelKeys', {
    matchLabelKeys: k.get(term, '$matchLabelKeys', []),
  })

  + k.onlyIfHas(term, '$mismatchLabelKeys', {
    mismatchLabelKeys: k.get(term, '$mismatchLabelKeys', []),
  })
);

local podAffinityRequiredAllOf = function(allOf) [
  podAffinityTerm(allOf),
];

local podAffinityRequiredAnyOf = function(anyOf) [
  (
    podAffinityTerm(item.value, if std.isObject(anyOf) then item.key)
  )
  for item in util.getKeysValues(anyOf)
];

local podAffinityPreferredAllOf = function(allOf) [
  {
    weight: k.get(allOf, '$weight', 100),  // allow for an optional weight field to be set on the allOf selector, defaulting to 1 if not set
    podAffinityTerm: podAffinityTerm(allOf),
  },
];

local podAffinityPreferredAnyOf = function(anyOf) [
  {
    weight: k.get(item.value, '$weight', 100),  // allow for an optional weight field to be set on the anyOf selector, defaulting to 1 if not set
    podAffinityTerm: podAffinityTerm(item.value, if std.isObject(anyOf) then item.key),
  }
  for item in util.getKeysValues(anyOf)
];

// patch deployment/statefulset/daemonset configs with affinity rules based on simplified config from props
function(affinity={}) {
  local node = k.get(affinity, 'node', {}),  // node affinity config
  local pod = k.get(affinity, 'pod', {}),  // pod affinity

  spec+: {
    template+: {
      spec+:
        {}
        // add hard node selectors for simple key-value pairs in require
        + k.onlyIfHas(node, 'require', {
          local allOf = getAllOf(node.require),

          nodeSelector+: {
            [k.get(item.value, 'key', item.key)]: k.get(item.value, 'value', item.value)
            for item in util.getKeysValues(allOf)
            if std.isString(k.get(item.value, 'value', item.value))
          },
        })

        // add node affinity rules for more complex selectors in require
        + k.onlyIfHas(node, 'require', (
          local allOf = {
            [item.key]: item.value
            for item in util.getKeysValues(getAllOf(node.require))
            if !std.isString(k.get(item.value, 'value', item.value))
          };

          local anyOf = getAnyOf(node.require);  // allow for an optional anyOf list for OR logic between selectors

          k.onlyIf(std.length(allOf) > 0 || std.length(anyOf) > 0, {
            affinity+: {
              nodeAffinity+: {
                requiredDuringSchedulingIgnoredDuringExecution+:
                  {}

                  // for all simple selectors under require, add them as match expressions under a single node selector term, allowing for AND logic between them
                  + k.onlyIf(std.length(allOf) > 0, {
                    nodeSelectorTerms+: [
                      {
                        matchExpressions+: matchExpressions(allOf),
                      },
                    ],
                  })

                  // if there are any selectors under anyOf, add an additional node selector term for each one, allowing for OR logic between them
                  + k.onlyIf(std.length(anyOf) > 0, {
                    nodeSelectorTerms+: [
                      {
                        matchExpressions+: matchExpressions(
                          if std.isArray(anyOf) then item.value else { [item.key]: item.value },
                        ),
                      }
                      for item in util.getKeysValues(anyOf)
                    ],
                  }),
              },
            },
          })
        ))


        // add preferred node affinity rules for selectors in prefer
        + k.onlyIfHas(node, 'prefer', {
          local allOf = getAllOf(node.prefer),
          local anyOf = getAnyOf(node.prefer),
          affinity+: {
            nodeAffinity+: {
              preferredDuringSchedulingIgnoredDuringExecution+:
                []

                //
                + k.onlyIfArr(std.length(allOf) > 0, [
                  {
                    weight: k.get(allOf, '$weight', 100),  // allow for an optional weight field to be set on the allOf selector, defaulting to 1 if not set
                    preference: {
                      matchExpressions: matchExpressions(allOf),
                    },
                  },
                ])

                + k.onlyIfArr(std.length(anyOf) > 0, [
                  {
                    weight: k.get(item.value, '$weight', 100),  // allow for an optional weight field to be set on the anyOf selector, defaulting to 1 if not set
                    preference: {
                      matchExpressions: matchExpressions(
                        if std.isArray(anyOf) then item.value else { [item.key]: item.value },
                      ),
                    },
                  }
                  for item in util.getKeysValues(node.prefer)
                ]),
            },
          },
        })

        + k.onlyIfHas(pod, 'require', {
          local allOf = getAllOf(pod.require),
          local anyOf = getAnyOf(pod.require),

          affinity+: {
            podAffinity+: {
              requiredDuringSchedulingIgnoredDuringExecution+:
                []
                + k.onlyIfArr(std.length(allOf) > 0, podAffinityRequiredAllOf(allOf))
                + k.onlyIfArr(std.length(anyOf) > 0, podAffinityRequiredAnyOf(anyOf)),
            },
          },
        })

        + k.onlyIfHas(pod, 'prohibit', {
          local allOf = getAllOf(pod.prohibit),
          local anyOf = getAnyOf(pod.prohibit),

          affinity+: {
            podAntiAffinity+: {
              requiredDuringSchedulingIgnoredDuringExecution+:
                []
                + k.onlyIfArr(std.length(allOf) > 0, podAffinityRequiredAllOf(allOf))
                + k.onlyIfArr(std.length(anyOf) > 0, podAffinityRequiredAnyOf(anyOf)),
            },
          },
        })

        + k.onlyIfHas(pod, 'prefer', {
          local allOf = getAllOf(pod.prefer),
          local anyOf = getAnyOf(pod.prefer),

          affinity+: {
            podAffinity+: {
              preferredDuringSchedulingIgnoredDuringExecution+:
                []
                + k.onlyIfArr(std.length(allOf) > 0, podAffinityPreferredAllOf(allOf))
                + k.onlyIfArr(std.length(anyOf) > 0, podAffinityPreferredAnyOf(anyOf)),
            },
          },
        })

        + k.onlyIfHas(pod, 'avoid', {
          local allOf = getAllOf(pod.avoid),
          local anyOf = getAnyOf(pod.avoid),

          affinity+: {
            podAntiAffinity+: {
              preferredDuringSchedulingIgnoredDuringExecution+:
                []
                + k.onlyIfArr(std.length(allOf) > 0, podAffinityPreferredAllOf(allOf))
                + k.onlyIfArr(std.length(anyOf) > 0, podAffinityPreferredAnyOf(anyOf)),
            },
          },
        })


        // topology spread constraints for simple key-value pairs in spread
        + k.onlyIfHas(affinity, 'spread', {
          topologySpreadConstraints+: [
            (
              {
                maxSkew: k.get(item.value, '$skew', 1),
                topologyKey: item.key,
                whenUnsatisfiable: if k.get(item.value, '$strict', true) then 'DoNotSchedule' else 'ScheduleAnyway',
                labelSelector: {
                  matchExpressions: matchExpressions(item.value),
                },
              }
              // optional minDomains
              + k.onlyIfHas(item.value, '$min', {
                minDomains: item.value['$min'],
              })
            )
            for item in util.getKeysValues(affinity.spread)
          ],
        }),
    },
  },
}
