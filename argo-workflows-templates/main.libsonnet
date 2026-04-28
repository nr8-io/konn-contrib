local util = import 'konn-contrib/util/main.libsonnet';
local k = import 'konn/main.libsonnet';

//
local transformContainerTemplate = import './transformers/container.libsonnet';
local transformScriptTemplate = import './transformers/script-template.libsonnet';

// use an object key as a value or the item key, if the item key is a number then use a prefix + the key to create a string value
local useKey = function(item, key='key', prefix='', separator='-',) (
  k.get(item.value, key, if std.isNumber(item.key) then prefix + separator + std.toString(item.key) else std.toString(item.key))
);

k.feature([
  // create rbac resources for argo workflows if rbac config is supplied
  function(ctx, props) (import '../argo-workflows-rbac/manifests/argo-workflows-workflow-rbac.libsonnet').apply({
    namespace: props.namespace,
    workflows: {
      [useKey(workflow, 'name', 'workflow')]: workflow.value.rbac
      for workflow in util.getKeysValues(props.workflows)
      if std.objectHas(workflow.value, 'rbac')
    },
  }),

  function(ctx, props) std.flattenArrays([
    (
      [
        k.yaml(importstr './templates/argo-wf-base-template.yaml', {
          namespace: props.namespace,
          name: useKey(workflow, 'name', prefix='workflow'),
        })

        + {
          spec+:
            // override using default workflow spec filtering extended config values
            {
              [item.key]: item.value
              for item in std.objectKeysValues(workflow.value)
              if !std.contains(['rbac'], item.key)
            }

            // add service account to workflow spec if rbac config defined for this workflow
            + k.onlyIfHas(workflow.value, 'rbac', {
              serviceAccountName: k.get(workflow.value.rbac, 'name', 'argo-wf-workflow-' + useKey(workflow, 'name', 'workflow')),
            })

            // apply script template transformation if script field defined in config for this workflow
            + {
              templates: [
                (
                  template.value {
                    name: useKey(template, 'name', prefix='template'),
                  }

                  // add script template overrides
                  + k.onlyIfHas(template.value, 'script', {
                    script: transformScriptTemplate(template.value.script),
                  })

                  // add container template overrides
                  + k.onlyIfHas(template.value, 'container', {
                    container: transformContainerTemplate(template.value.container),
                  })
                )
                for template in util.getKeysValues(workflow.value.templates)
              ],
            }

            // add default entrypoint if not defined in config for this workflow
            + k.onlyIf(!std.objectHas(workflow.value, 'entrypoint'), {
              entrypoint: super.templates[0].name,
            }),
        },
      ]
    )
    for workflow in util.getKeysValues(props.workflows)
  ]),
], {
  namespace: 'argo',
  workflows: {},
})
