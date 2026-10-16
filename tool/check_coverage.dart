import 'dart:io';

void main(List<String> args) {
  var hit = 0;
  var found = 0;
  for (final line in File(args.single).readAsLinesSync()) {
    if (line.startsWith('LH:')) hit += int.parse(line.substring(3));
    if (line.startsWith('LF:')) found += int.parse(line.substring(3));
  }
  if (found == 0) {
    stderr.writeln('Coverage is missing.');
    exitCode = 2;
    return;
  }
  final coverage = hit * 100 / found;
  stdout.writeln('$hit / $found = ${coverage.toStringAsFixed(3)}%');
  if (coverage < 90) exitCode = 1;
}
