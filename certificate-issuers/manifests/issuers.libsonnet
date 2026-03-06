local k = import 'konn/main.libsonnet';

k.manifest(function(ctx, props) [
  {
    apiVersion: 'cert-manager.io/v1',
    kind: k.onlyIfHas(issuer.value, 'kind', issuer.value.kind, 'Issuer'),
    metadata: {
      name: issuer.key,

    } + k.onlyIfHas(issuer.value, 'namespace', {
      namespace: issuer.value.namespace,
    }),
    spec:
      {}
      + k.onlyIfHas(issuer.value, 'selfSigned', {
        selfSigned: {},
      })
      + k.onlyIfHas(issuer.value, 'acme', {
        local config = issuer.value.acme,

        acme: {
          server: k.onlyIfHas(config, 'server', config.server, 'https://acme-v02.api.letsencrypt.org/directory'),
          email: k.onlyIfHas(config, 'email', config.email, 'domains@example.co'),
          privateKeySecretRef: {
            name: issuer.key + '-acme-key',
          },
          solvers:
            []
            // http01 solver
            + k.onlyIfHas(config, 'http', [{
              http01: {
                ingressClass: k.onlyIfHas(config.http, 'ingressClass', config.http.ingressClass, 'apisix'),
              },
            }], [])
            // cloudflare dns01 solver
            + k.onlyIfHas(config, 'cloudflare', [{
              dns01: {
                cloudflare:
                  {
                    apiKeySecretRef: k.onlyIfHas(config.cloudflare, 'secret', config.cloudflare.secret, {
                      name: 'cloudflare',
                      key: 'token',
                    }),
                  }
                  + k.onlyIfHas(config.cloudflare, 'email', {
                    email: config.cloudflare.email,
                  }),
              },
            }], []),
        },
      }),
  }
  for issuer in std.objectKeysValues(props.issuers)
], {
  issuers: {},
})
