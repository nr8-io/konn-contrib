local k = import 'konn/main.libsonnet';

// create rbac rule based on users and groups
local rbacRule = function(users=[], groups=[]) (
  if (std.length(users) > 0 && std.length(groups) > 0) then
    'any(' + std.manifestJsonMinified(groups) + ', { # in groups }) || any(' + std.manifestJsonMinified(users) + ', { # == email })'
  else if (std.length(users) > 0) then
    'any(' + std.manifestJsonMinified(users) + ', { # == email })'
  else if (std.length(groups) > 0) then
    'any(' + std.manifestJsonMinified(groups) + ', { # in groups })'
  else
    'false'
);

// create rbac resources for argo workflows users
k.manifest(function(ctx, props) std.flattenArrays([
  (
    [
      // create service account for user with rbac rule annotation to match
      // sso users
      k.yaml(importstr '../templates/argo-workflows-user-rbac-sa.yaml', {
        rbacRule: rbacRule(k.get(item.value, 'users', []), k.get(item.value, 'groups', [])),
        name: k.get(item.value, 'name', 'argo-wf-user-' + item.key),
        namespace: props.namespace,
      }),

      k.yaml(importstr '../templates/argo-workflows-user-rbac-sa-secret.yaml', {
        name: k.get(item.value, 'name', 'argo-wf-user-' + item.key),
        namespace: props.namespace,
      }),

      // create a role for minimal workflow access, extend with additional rules if needed
      k.yaml(importstr '../templates/argo-workflows-user-rbac-role.yaml', {
        namespace: props.namespace,
        name: k.get(item.value, 'name', 'argo-wf-user-' + item.key),
      }) + {
        // scope role rules to specific workflow templates if defined for user
        rules:
          super.rules[0:-1]  // minimal default workflow permissions
          // specific workflow template permissions from config
          + [
            super.rules[std.length(super.rules) - 1] {
              resourceNames: k.get(item.value, 'workflows', []),
            },
          ]
          // additional custom rules from config
          + k.get(item.value, 'rules', []),
      },

      // bind role to service account
      k.yaml(importstr '../templates/argo-workflows-user-rbac-rb.yaml', {
        namespace: props.namespace,
        name: k.get(item.value, 'name', 'argo-wf-user-' + item.key),
      }),
    ]

    // create kyverno policy to restrict workflow creation to allowed templates for this user
    + k.onlyIfArr(props.validationPolices, [
      k.yaml(importstr '../templates/argo-workflows-user-rbac-nvpol.yaml', {
        namespace: props.namespace,
        name: k.get(item.value, 'name', 'argo-wf-user-' + item.key),
        workflowTemplates: std.manifestJsonMinified(k.get(item.value, 'workflows', [])),
      }) + {
        spec+: k.get(props, 'spec', {}),
      },
    ])
  )
  for item in std.objectKeysValues(props.users)
]), {
  users: {},
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
