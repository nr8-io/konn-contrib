local k = import 'konn/main.libsonnet';

function(path, pos=null, separator='/') (
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
)
