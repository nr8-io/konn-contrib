local path = import '../util/path-selector.libsonnet';
local k = import 'konn/main.libsonnet';

local pathSelector = function(selector) function(ctx, target, props) (
  local parts = path.parse(selector);


  if (std.length(parts) == 1) then
    target.is(parts[0][0])
  else if (std.length(parts) == 2) then
    target.is(parts[0][0], parts[1][0])
  else if (std.length(parts) == 3) then
    target.get('metadata.namespace') == parts[0][0] && target.is(parts[1][0], parts[2][0])
  else
    false
);

local patchYaml = function(selector, template, defaults={}) (
  k.extension(
    function(ctx, target, props) (
      k.patch(target, k.yaml(template, props, interpolation=true))
    ),
    defaults,
    selector=pathSelector(selector)
  )
);

local patchJson = function(selector, template, defaults={}) (
  k.extension(
    function(ctx, target, props) (
      k.patch(target, k.json(template, props, interpolation=true))
    ),
    defaults,
    selector=pathSelector(selector)
  )
);

local patchFunction = function(selector, fn=function(props) {}, defaults={}) (
  k.extension(
    function(ctx, target, props) (
      target + fn(props)
    ),
    defaults,
    selector=pathSelector(selector)
  )
);

{
  yaml: patchYaml,
  json: patchJson,
  fn: patchFunction,
}
