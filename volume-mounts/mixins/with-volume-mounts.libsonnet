local util = import '../../util/main.libsonnet';
local selector = import '../../util/path-selector.libsonnet';
local k = import 'konn/main.libsonnet';

local parseVolume = function(key, value={}) (
  local parts = selector.parse(key);  // parse selector into path segments

  // get the volume type and name from the selector, defaulting to PVC and volume name if not specified
  local type = std.asciiLower(if std.length(parts) > 1 then parts[0][0] else 'pvc');
  local name = std.asciiLower(if std.length(parts) > 1 then parts[1][0] else parts[0][0]);

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

function(volumes={}, name=null) {
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
                  local shouldMount = (
                    name == null && std.isArray(item.value) ||  // mount all containers
                    name == null && std.isObject(item.value) && mount.key == container.name ||  // mount single specific container
                    name == null && std.isObject(item.value) && selector.contains(mount.key, container.name, 0) ||  // mount multiple specific containers using selector syntax in the mount key, e.g. "nginx" or "[nginx, php]"
                    selector.isTarget(mount.key, name, container.name)  // mount using target/[container] selector syntax, used in extensions
                  );

                  // only add the volume mount if the selector matches the deployment and container
                  k.onlyIfArr(shouldMount, (
                    parseMount(volume.name, mount.value)
                  ))
                ),
                util.getKeysValues(item.value)  // mount targets, selector/paths or array of paths
              )
            ),
            std.objectKeysValues(volumes)  // volume selectors
          ),
        }, super.containers),

        // add volumes to pod spec if they match one of the selectors
        volumes+: [
          parseVolume(item.key, item.value)
          for item in std.objectKeysValues(volumes)
          if name == null || selector.contains(std.objectFields(item.value), name, 0)
        ],
      },
    },
  },
}
