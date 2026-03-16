local k = import 'konn/main.libsonnet';

local parse = function(path, pos=null, separator='/') (
  // magic to support values inside of []
  local sections = std.split(std.strReplace(std.strReplace(separator + path, '[', '%{'), ']', '}%'), '%');

  // slit dot notation if not inside of [...] sections
  local keys = std.filter(function(key) key != '', std.flatMap(function(part) (
    if std.startsWith(part, separator) then (
      std.split(part, separator)
    ) else if std.startsWith(part, '{') && std.endsWith(part, '}') then (
      [part[1:-1]]
    ) else (
      [part]
    )
  ), sections));

  local result = std.map(
    function(sel) (
      std.split(sel, ',')
    ),
    // split main selector into deploy/container parts, e.g. "silverstripe/[nginx, php]" -> ["silverstripe", "[nginx, php]"]
    keys
  );

  if std.isNumber(pos) then (
    if std.length(result) > pos then (
      result[pos]
    ) else (
      []
    )
  ) else (
    result
  )
);

local contains = function(pathOrPaths, name, index=0) (
  local paths = if std.isArray(pathOrPaths) then pathOrPaths else [pathOrPaths];

  local targets = std.flatMap(function(path) (
    parse(path, index)
  ), paths);

  std.contains(targets, name)
);

local isEmpty = function(selectors=[], index=0) (
  local targets = std.flatMap(function(path) (
    parse(path, index)
  ), selectors);

  std.length(targets) == 0
);

local isTarget = function(pathOrPaths, deployment, container) (
  local paths = if std.isArray(pathOrPaths) then pathOrPaths else [pathOrPaths];

  contains(paths, deployment, 0) && (contains(paths, container, 1) || isEmpty(paths, 1))
);

{
  parse: parse,
  contains: contains,
  isEmpty: isEmpty,
  isTarget: isTarget,
}
