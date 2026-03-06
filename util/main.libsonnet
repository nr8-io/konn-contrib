local k = import 'konn/main.libsonnet';
local pathSelector = './path-selector.libsonnet';

// return true if the object has at least one of the specified keys
local objectHasOneOf = function(obj, keys=[]) (
  std.length(std.filter(function(key) std.objectHas(obj, key), keys)) > 0
);

// return the first non-null value from an array, or null if all values are null
local getFirstNonNull = function(target, paths=[], default=null) (
  local result = std.filter(function(path) k.get(target, path) != null, paths);

  if std.length(result) > 0 then k.get(target, result[0]) else default
);

{
  pathSelector: pathSelector,
  objectHasOneOf: objectHasOneOf,
  getFirstNonNull: getFirstNonNull,
}
