local k = import 'konn/main.libsonnet';

// simplified port config that supports targetPort:port syntax in addition to standard Kubernetes Service port definitions
local parsePort = function(config) (
  // if the port is a string in the format "targetPort:port", split it into targetPort and port, otherwise use the config as-is
  local ports = if std.isString(config.port) then std.split(config.port, ':') else [config.port];

  config + k.onlyIf(std.length(ports) > 1, {
    port: std.parseInt(ports[0]),
    targetPort: std.parseInt(ports[1]),
  })
);

// simplified ApisixRoute configuration for basic HTTP routing, without upstreams or plugins
k.manifest(function(ctx, props) [
  {
    apiVersion: 'v1',
    kind: 'Service',
    metadata: {
      name: service.key,
    } + k.onlyIfHas(service.value, 'namespace', {
      namespace: service.value.namespace,
    }),
    spec:
      {
        type: k.get(service.value, 'type', 'ClusterIP'),
      }
      + k.onlyIfHas(service.value, 'port', {
        local config = parsePort(service.value),

        ports: [
          {
            protocol: k.get(config, 'protocol', 'TCP'),
            port: config.port,
          }
          + k.onlyIfHas(config, 'targetPort', {
            targetPort: config.targetPort,
          })
          // optional port name
          + k.onlyIfHas(config, 'name', {
            name: config.name,
          }),
        ],
      })
      // optional ports in standard Kubernetes Service format, will override simplified port/targetPort if provided
      + k.onlyIfHas(service.value, 'ports', {
        ports: [
          local config = if std.isString(port) then parsePort({ port: port }) else parsePort(port);

          {
            type: k.get(config, 'protocol', 'TCP'),
            port: config.port,
          }
          + k.onlyIfHas(config, 'targetPort', {
            targetPort: config.targetPort,
          })
          for port in service.value.ports
        ],
      })
      // optional selector, will default to matching service name if not provided
      + k.onlyIfHas(service.value, 'selector', {
        selector: service.value.selector,
      }, {
        selector: {
          name: service.key,
        },
      }),
  }
  for service in std.objectKeysValues(props.services)
], {
  services: {},
})
