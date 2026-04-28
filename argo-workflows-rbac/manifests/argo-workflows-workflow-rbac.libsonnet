local k = import 'konn/main.libsonnet';

// create exec rule expression based on pod and container config
local execExpr = function(pod=null, container=null) (
  if pod != null && container != null then
    'request.name.startsWith("' + pod + '") && object.container == "' + container + '"'
  else if pod != null then
    'request.name.startsWith("' + pod + '")'
  else if container != null then
    'object.container == "' + container + '"'
  else
    'false'
);

local resourceNames = function(rules=[]) (
  [
    (
      if std.isString(rule) then
        rule
      else if std.isObject(rule) then
        k.get(rule, 'target', null)
    )
    for rule in rules
    if std.isString(rule) || k.get(rule, 'target', null) != null
  ]
);

local execValidation = function(rules=[]) std.join(' || \n', [
  (
    if std.isString(rule) then
      execExpr(rule)
    else if std.isObject(rule) then
      execExpr(k.get(rule, 'target', null), k.get(rule, 'container', null))
    else
      'false'
  )
  for rule in rules
]);


// create rbac resources for argo workflows users
k.manifest(function(ctx, props) std.flattenArrays([
  (
    [
      // create service account for workflow
      k.yaml(importstr '../templates/argo-workflows-workflow-rbac-sa.yaml', {
        name: k.get(item.value, 'name', 'argo-wf-workflow-' + item.key),
        namespace: props.namespace,
      }),

      // create a role for the workflow with permissions based on config, extend with additional rules if needed
      k.yaml(importstr '../templates/argo-workflows-workflow-rbac-role.yaml', {
        name: k.get(item.value, 'name', 'argo-wf-workflow-' + item.key),
        namespace: props.namespace,
      }) + {
        // extend role with additional rules if needed
        rules:
          []
          + super.rules  // default rules for workflow execution
          + k.get(item.value, 'rules', [])  // additional custom rules from config

          // add exec permissions if scoped exec access defined in config for this workflow
          + k.onlyIfHasArr(item.value, 'exec', [
            {
              apiGroups: ['apps'],
              resources: ['deployments', 'statefulsets', 'daemonsets'],
              resourceNames: resourceNames(k.get(item.value, 'exec', [])),
              verbs: ['get'],
            },
            {
              apiGroups: [''],
              resources: ['pods'],
              verbs: ['list'],
            },
            {
              apiGroups: [''],
              resources: ['pods/exec'],
              verbs: ['create'],
            },
          ]),
      },

      k.yaml(importstr '../templates/argo-workflows-workflow-rbac-rb.yaml', {
        name: k.get(item.value, 'name', 'argo-wf-workflow-' + item.key),
        namespace: props.namespace,
      }),
    ]

    // add exec kyverno policy to restrict exec access to workflow pods
    + k.onlyIfArr(k.get(item.value, 'exec') != null && props.validationPolices, [
      // create kyverno policy to restrict exec access to workflow pods
      k.yaml(importstr '../templates/argo-workflows-workflow-rbac-exec-nvpol.yaml', {
        name: k.get(item.value, 'name', 'argo-wf-workflow-' + item.key),
        namespace: props.namespace,
      }) + {
        // add validation rule to check if the exec request matches the allowed pod/container rules defined in config for this workflow
        spec+: {
          validations: [
            {
              expression: execValidation(item.value.exec),
              messageExpression: '"User is not allowed to execute commands on this pod."',
            },
          ],
        },
      } + {
        spec+: k.get(props, 'spec', {}),
      },
    ])
  )
  for item in std.objectKeysValues(props.workflows)
]), {
  workflows: {},
  validationPolices: true,
  validationPolicy: {
    apiVersion: 'kyverno.io/v1',
    kind: 'NamespacedValidationPolicy',
  },
  spec: {
    evaluation: {
      admission: {
        enabled: true,
      },
      background: {
        enabled: false,
      },
    },
  },
})
