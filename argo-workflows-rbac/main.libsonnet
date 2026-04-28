local k = import 'konn/main.libsonnet';

k.feature([
  // grant admin permissions for argo workflows and pods in this namespace
  function(ctx, props) k.yaml(importstr './templates/argo-workflows-admin-rbac-role.yaml', {
    namespace: props.namespace,
  }),

  // bind admin role to service account used for argo workflow admin
  function(ctx, props) k.yaml(importstr './templates/argo-workflows-admin-rbac-rb.yaml', {
    namespace: props.namespace,
  }),

  import './manifests/argo-workflows-user-rbac.libsonnet',
  import './manifests/argo-workflows-workflow-rbac.libsonnet',
], {
  namespace: 'argo',
  users: {},
  workflows: {},

  // if validation policies should be created to enforce rbac rules on workflow
  // creation, requires kyverno or ValidatingAdmissionPolicy support in cluster
  validationPolices: true,
  // default to kyverno validation policy, can be switched to
  // ValidatingAdmissionPolicy if cluster supports and you prefer that or any
  // other compatible policy engine
  validationPolicy: {
    apiVersion: 'kyverno.io/v1',
    kind: 'NamespacedValidationPolicy',
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
  },
})
