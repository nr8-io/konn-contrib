## single template workflows

These are single template single entry point, pretty common and need minimal
config but the minute any extra config is needed template/templates should be 
used to supply the overrides, it doesn't make sense to allow top level overrides
without getting way to complex and having too many conflicts

For the most part there are no conflicts for steps, script, container, suspend,
http or resource on WorkflowSpec, same for dag but would rename to tasks to make more obvious
since 99% of the time no one needs to access anything extra in the dag spec

Creating a single simple workflow script should be quick, easy and painless

See specific examples of steps/dag/tasks for those use cases since I have better
ideas to make inlining easier

Suspend is pretty pointless for single workflow templates, but for the sake of
completeness I would add it just because...

all of these examples assume transformers provided by this lib

```yaml
workflows:
  script-example:
    script: |
      kubectl exec deploy/php -- composer install
  example-container:
    container:
      image: mysql
      command: ["/bin/bash", "-c"]
      args: ['echo "Hello World"']
  example-suspend:
    suspend: 30s # cause I am a maniac
  example-http:
    http:
      url: "http://httpbin.org/post"
      method: POST
  example-resource:
    resource: 
      method: delete
      manifest: |
        apiVersion: apps/v1
          kind: Deployment
          metadata:
            name: nginx
```

## global settings for template defaults

Would apply to all template types by default overriding the lib provided
defaults

In this case we want all resource templates to use patch, or http to use DELETE

allows minimal config at the dev/user level when configuring workflows for a
project and allows ops team to apply sane defaults specific to the project via
profiles

```yaml
workflows-config:
  resource:
    action: patch
  http:
    method: DELETE
```

## general concept key based expansions

not necessarily limited to this workflows lib but as a general config idea
for creating short hand configs, have used something similar in volumes with
path selectors but they are for taking values directly out of the key, rather
these would just be used as a common way to apply specific default sets which
mostly avoids conflicts in most existing specs

eg. taking an existing key and extending with dot.notation can be used to apply 
preconfigured defaults, eg. `http.post` creates http with method POST
`resource.apply` would create resource with action apply, could be provided via
global config

Rough idea on now this could be supplied as generic sets for different projects
or to be extended easily by ops/devs.

```yaml
workflow-expansions:
  # key is used by the feature/manifest to find expansion rules for a key
  templates.http:
    # name of the expansion to be matched which contains patch values
    http.delete:
      method: DELETE
    http.post:
      method: POST
    # example preset, can be included via http.my-ping: {}
    http.my-ping:
      method: POST
      timeoutSeconds: 5s
      header:
        - name: "x-ping-auth"
          value: "ping-token"
      url: "http://ping.svc/ping"
      body: |
        {"ok": true}

  templates.resource:
    resource.patch:
      action: patch
      mergeStrategy: merge
```

## suspend transformer

Simple, allow suspend value to be given as a string and convert to correct shape

```yaml
# if string is provided
suspend: 30s
# becomes
suspend:
  duration: 30s
```

## http transformer

Simple, allows quick requests using configured defaults

```yaml
# if string is provided
http: "https://httpbin.org/get"
# becomes
http:
  url: "https://httpbin.org/get"
```

Possible ideas for key based expansions,

```yaml
# if string is provided
http.get: "https://httpbin.org/get"
# becomes
http:
  method: GET
  url: "https://httpbin.org/get"

# if string is provided
http.post: "https://httpbin.org/get"
# becomes
http:
  method: POST
  url: "https://httpbin.org/get"
# etc...
```

## resource transformer

Same as others, allows manifest as string using the default configured action,
this lib will use "patch:merge" as the default since its probably my most common
use case

```yaml
# if string is provided
resource: |
  apiVersion: "stable.example.com/v1"
  kind: CronTab
  spec:
    cronSpec: "* * * * */10"
    image: my-awesome-cron-image
# becomes
resource:
  manifest: |
    apiVersion: "stable.example.com/v1"
    kind: CronTab
    spec:
      cronSpec: "* * * * */10"
      image: my-awesome-cron-image
```

Possible ideas for key based expansions,

```yaml
# if string is provided
http.get: "https://httpbin.org/get"
# becomes
http:
  method: GET
  url: "https://httpbin.org/get"

# if string is provided
http.post: "https://httpbin.org/get"
# becomes
http:
  method: POST
  url: "https://httpbin.org/get"
# etc...
```

## steps expansions

steps is list of list by default, to simplify single sequential steps allow
single list and convert to list of lists by defualt

```yaml
workflows:
  example-steps:
    steps:
      - name: step1
        template: step1-template
      - name: step2
        template: step2-template
# becomes
workflows:
  example-steps:
    steps:
      - - name: step1
          template: step1-template
      - - name: step2
          template: step2-template
```

eg. if the step is an object, wrap it in an array, if an array is supplied
assume defaults

### auto inlining of templates, single templates

Automatically inline templates if an object is provided to "template" rather
than requiring a specific "inline" prop, support all existing template
transformations.

```yaml
workflows:
  example-steps:
    # single workflow template
    steps:
      - script: |
          kubectl rollout restart deploy/nginx
      - http.post: "http://notify.svc/pod-restarted" 
```

Should support single scripts no problem as well which will be automatically
inlined so the value of each step is basically the same as any workflow template
config

steps still needs to be an array and can't support key/name and ensure the
correct order, but we can auto name steps if not included using the workflow
name, eg "example-steps-0", "example-steps-0" which is used already templates
naming if key/value or array with no names is provided

These adjustments bring the simplest multi-step workflows to something like
the above making use of existing transformations assumed on templates but still
supports full workflows spec where needed for customizing


### auto inlining of templates for dag

Same concept as above but we add another template key for dag since its a stupid
name that most people won't understand and just call it tasks, but both will
still be supported

dag tasks can key/value config for naming since its order uses deps instead of
order like steps. can still provide a normal tasks array following the same
ideas everywhere else, will be auto named if not provided, but not recommended

```yaml
workflows:
  example-steps:
    tasks:
      task1:
        script: |
          echo "task 1 complete"
      task2:
        dependencies: [task1] 
        script: |
          echo: "task 2 complete"
      task3:
        dependencies: [task1] 
        script: |
          echo "task 3 complete"
      task4:
        dependencies: [task2, task3] 
        script: |
          echo "task 4 complete"
    tasks.failFast: {} # alias to dag.failFast= true
    dag: # normal dag template as single template
      tasks: {}
    
    # full, but not sure why you'd want to
    templates:
      my-dag:
        dag:
          tasks: {}
```

Inline mode config

```yaml
workflows-config:
  inlineMode: "native|simulated"
```

Simulated inline mode will create templates under "spec.templates" and create
dag/steps using the template names, Native inline mode will use the inline prop
supplied by argo-workflows, partly because I want to make this for an example
and partly for workflows compat even though I don't personally have that issue
it might be nice

## template params/artifacts

arguments/artifacts don't conflict with template spec so they can be used as 
direct subs instead of input.arguments, input.artifacts,

parameters are added to templates by default unless otherwise supplied

inputs don't conflict and can be used directly but the string template reference
will still need to refer to input.parameters.

outputs work as normal on templates but inputs is assumed for parameters,
artifacts used at Template level for simplicity

Artifacts automatically added, opt out by settings artifacts: []

```yaml
workflows:
  my-workflow:
    parameters: # implies arguments.parameters
      - param1
    templates:
      my-template: # Template
        # implies inputs.parameters = ["param1"]" from template parameters unless overwritten
        # parameters expanded to input.parameters because no conflict
        script: |
          echo "{{inputs.parameters.parma1}}
```


```yaml
workflows:
  my-workflow:
    parameters:
      - param1
      - param2
    script: # Template
      parameters: ["param2"] # only param2 taken from template
      source: |
        echo "{{inputs.parameters.param2}}
```

## Parameters/Artifacts

expand name:value params for simplicity

Artifacts to name:path instead of name:value, same rules apply

```yaml
parameters:
  - key
# becomes
parameters:
  - name: key
```

```yaml
parameters:
  key: value
# becomes
parameters:
  - name: key
    value: value
```

```yaml
parameters:
  key:
    valueFrom:
      configMapKeyRef:
        name: my-cm
        key: my-key
# becomes
parameters:
  - name: key
    valueFrom:
      configMapKeyRef:
        name: my-cm
        key: my-key
```

