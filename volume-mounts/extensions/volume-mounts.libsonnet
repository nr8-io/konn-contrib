local selector = import '../../util/path-selector.libsonnet';
local k = import 'konn/main.libsonnet';

// helper function to check if a name is in the list of selectors for a given position
local contains = function(selectors, name, index=0) (
  local targets = std.flatMap(function(path) (
    selector(path, index)
  ), selectors);

  std.contains(targets, name)
);

// helper function to check if there are no selectors for a given position (i.e. selector is empty, meaning it matches all)
local isEmpty = function(selectors, index=0) (
  local targets = std.flatMap(function(path) (
    selector(path, index)
  ), selectors);

  std.length(targets) == 0
);

// check if a given volume mount selector matches the deployment and container
local isTarget = function(key, deployment, container) (
  contains([key], deployment, 0) && (contains([key], container, 1) || isEmpty([key], 1))
);

local parseVolume = function(key, value={}) (
  local path = selector(key);  // parse selector into path segments

  // get the volume type and name from the selector, defaulting to PVC and volume name if not specified
  local type = std.asciiLower(if std.length(path) > 1 then path[0][0] else 'pvc');
  local name = std.asciiLower(if std.length(path) > 1 then path[1][0] else path[0][0]);

  {
    name: name,
  }

  // persistent volume claims
  + k.onlyIf(type == 'pvc' || type == 'persistentvolumeclaim', {
    persistentVolumeClaim: {
      claimName: name,
    },
  })

  // config map volumes
  + k.onlyIf(type == 'cm' || type == 'configmap', {
    configMap: {
      name: name,
    },
  })

  // empty dir volumes
  + k.onlyIf(type == 'emptydir' || type == 'empty', {
    emptyDir: {},
  })

  // host path volumes, uses hash from path for naming
  + k.onlyIf(type == 'host' || type == 'hostpath', {
    name: 'host-' + std.md5(name)[0:8],  // hash the path to create a unique name for the volume
    hostPath: {
      path: name,
    },
  })

  // volumes from secrets
  + k.onlyIf(type == 'secret', {
    secret: {
      secretName: name,
    },
  })
);

// simplified port config that supports targetPort:port syntax in addition to standard Kubernetes Service port definitions
local parseMount = function(name, value) (
  local config = if std.isString(value) then {
    path: value,
  } else if std.isArray(value) then {
    paths: value,
  } else (
    value
  );

  [
    {
      name: name,
    }
    // path as string
    + k.onlyIf(std.isString(path), (
      // split path into mountPath and subPath if using "subPath:mountPath" syntax, otherwise use the path as the mountPath
      local parts = if std.isString(path) then std.split(path, ':') else [path];

      {
        mountPath: parts[0],
      }
      // add subPath if using "subPath:mountPath" syntax
      + k.onlyIf(std.length(parts) > 1, {
        mountPath: parts[1],
        subPath: parts[0],
      })
    ))
    // if path is an object, use it as the config directly (allows for full customization of volume mounts in the selector)
    + k.onlyIf(std.isObject(path), path)
    // add any additional config from the value of the mount selector, excluding the path which is used for the mountPath/subPath
    + {
      [item.key]: item.value
      for item in std.objectKeysValues(config)
      if !std.contains(['path', 'paths'], item.key)  // filter out path/paths from config as they are not valid in Kubernetes Service port definitions
    }
    for path in k.get(config, 'paths', [k.get(config, 'path')])
  ]
);

// automatically add volume mounts to containers based on a selector syntax in the volume definition, e.g. "silverstripe/[nginx, php]" would add the volume to the nginx and php containers in the silverstripe deployment
k.extension(
  function(ctx, config, props) config {
    spec+: {
      template+: {
        spec+: {
          // map containers to add volume mounts based on selectors
          containers: std.map(function(container) container {
            // flat map volume mounts to check if volumes match the selector
            volumeMounts+: std.flatMap(
              // map over volume mounts in the config to check if they match the selector
              function(item) (
                local volume = parseVolume(item.key);  // parse selector into path segments

                std.flatMap(
                  // map over mounts in the volume config to check if they match the selector
                  function(mount) (
                    local shouldMount = isTarget(mount.key, config.metadata.name, container.name);

                    // only add the volume mount if the selector matches the deployment and container
                    k.onlyIfArr(shouldMount, parseMount(volume.name, mount.value))
                  ),
                  std.objectKeysValues(item.value)  // mount targets
                )
              ),
              std.objectKeysValues(props.mounts)  // volume selectors
            ),
          }, config.spec.template.spec.containers),

          // add volumes to pod spec if they match one of the selectors
          volumes+: [
            parseVolume(item.key, item.value)
            for item in std.objectKeysValues(props.mounts)
            if contains(std.objectFields(item.value), config.metadata.name, 0)
          ],
        },
      },
    },
  },
  {
    mounts: {},
  },
  selector=function(ctx, config, props) config.is('Deployment')
)
