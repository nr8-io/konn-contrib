local k = import 'konn/main.libsonnet';

// simplified ApisixRoute configuration for basic HTTP routing, without upstreams or plugins
k.manifest(function(ctx, props) [
  {
    apiVersion: 'apisix.apache.org/v2',
    kind: 'ApisixRoute',
    metadata: {
      name: route.key,
    },
    spec: {
      http: std.mapWithIndex(function(i, backend) (
        {
          // can be provided as ApisixRoute spec or simplified with top-level fields (host/hosts, path/paths, method/methods)
          backends: k.onlyIfHas(backend, 'backends', backend.backends, [
            {
              resolveGranularity: k.onlyIfHas(backend, 'granularity', backend.granularity, 'service'),
              serviceName: backend.service,
              servicePort: k.onlyIfHas(backend, 'port', backend.port, 80),
            },
          ]),
          // can be provided as ApisixRoute spec or simplified with top-level fields (host/hosts, path/paths, method/methods)
          match: k.onlyIfHas(
            backend,
            'match',
            backend.match,
            {
              paths: ['/*'],
            }
            // single host config
            + k.onlyIfHas(backend, 'host', {
              hosts: [backend.host],
            })
            // multiple hosts config
            + k.onlyIfHas(backend, 'hosts', {
              hosts: backend.hosts,
            })
            // single path config
            + k.onlyIfHas(backend, 'path', {
              paths: [backend.path],
            })
            // multiple paths config
            + k.onlyIfHas(backend, 'paths', {
              paths: backend.paths,
            })
            // exprs config
            + k.onlyIfHas(backend, 'exprs', {
              exprs: backend.exprs,
            })
            // single method config
            + k.onlyIfHas(backend, 'method', {
              methods: [backend.method],
            })
            // multiple methods config
            + k.onlyIfHas(backend, 'methods', {
              methods: backend.methods,
            })
          ),
          // name is optional, will default to route key + index if not provided
          name: k.onlyIfHas(backend, 'name', backend.name, route.key + '-' + std.toString(i)),
        }
        // plugin config name and namespace (defaults to 'casdoor' if plugin is specified without namespace)
        + k.onlyIfHas(backend, 'plugin', {
          plugin_config_name: backend.plugin,
          plugin_config_namespace: k.onlyIfHas(backend, 'plugin_namespace', backend.plugin_namespace, 'casdoor'),
        })
        // multiple plugins config provided as ApisixRoute plugins field
        + k.onlyIfHas(backend, 'plugins', {
          plugins: backend.plugins,
        })
        // When set to true enables websocket proxy.
        + k.onlyIfHas(backend, 'websocket', {
          websocket: backend.websocket,
        })
        // ApisixRoute authentication field for route-level authentication config, see ApisixRoute docs for details on authentication config format
        + k.onlyIfHas(backend, 'authentication', {
          authentication: backend.authentication,
        })
        // ApisixRoute priority field for route priority config
        + k.onlyIfHas(backend, 'priority', {
          priority: backend.priority,
        })
        // ApisixRoute timeout config for route timeout config, see ApisixRoute docs for details on timeout config format
        + k.onlyIfHas(backend, 'timeout', {
          timeout: backend.timeout,
        })
      ), route.value),
    },
  }
  for route in std.objectKeysValues(props.routes)
], {
  routes: {},
})
