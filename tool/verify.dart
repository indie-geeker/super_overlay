import 'dart:async';
import 'dart:convert';
import 'dart:io';

class VerifyStep {
  const VerifyStep(this.name, this.executable, this.arguments, this.directory);
  final String name;
  final String executable;
  final List<String> arguments;
  final String directory;
}

typedef StepExecutor = Future<int> Function(VerifyStep step, File log);

Future<int> executeStep(VerifyStep step, File log) async {
  final sink = log.openWrite();
  try {
    final process = await Process.start(
      step.executable,
      step.arguments,
      workingDirectory: step.directory,
      runInShell: Platform.isWindows,
    );
    final streams = [
      process.stdout.transform(utf8.decoder),
      process.stderr.transform(utf8.decoder),
    ];
    await Future.wait(
      streams.map((stream) async {
        await for (final chunk in stream) {
          sink.write(chunk);
          stdout.write(chunk);
        }
      }),
    );
    return await process.exitCode;
  } on ProcessException catch (error) {
    sink.writeln(error);
    stderr.writeln(error);
    return 127;
  } finally {
    await sink.close();
  }
}

/// Also used by tests with an injected executor to prove failures cannot be
/// hidden by logging or the remaining steps.
Future<int> runSteps(
  List<VerifyStep> steps,
  Directory output, {
  StepExecutor execute = executeStep,
  Map<String, Object?> metadata = const {},
}) async {
  output.createSync(recursive: true);
  final records = <Map<String, Object?>>[];
  var failure = 0;
  for (final step in steps) {
    final record = <String, Object?>{
      'name': step.name,
      'executable': step.executable,
      'arguments': step.arguments,
      'directory': step.directory,
    };
    records.add(record);
    if (failure != 0) {
      record['status'] = 'not-run';
      continue;
    }
    stdout.writeln('Checking ${step.name}');
    record['startedAt'] = DateTime.now().toUtc().toIso8601String();
    final log = File('${output.path}/${step.name}.log');
    record['log'] = log.path;
    try {
      failure = await execute(step, log);
    } catch (error, stack) {
      failure = 1;
      log.writeAsStringSync('$error\n$stack');
      stderr.writeln(error);
    }
    record['exitCode'] = failure;
    record['status'] = failure == 0 ? 'passed' : 'failed';
    record['finishedAt'] = DateTime.now().toUtc().toIso8601String();
  }
  File('${output.path}/report.json').writeAsStringSync(
    const JsonEncoder.withIndent(
      '  ',
    ).convert({'environment': metadata, 'exitCode': failure, 'steps': records}),
  );
  stdout.writeln('Verification report: ${output.path}/report.json');
  return failure;
}

String resolveFlutter(String value) {
  if (File(value).existsSync()) return File(value).absolute.path;
  for (final directory in (Platform.environment['PATH'] ?? '').split(
    Platform.isWindows ? ';' : ':',
  )) {
    final candidate = File(
      '$directory/$value${Platform.isWindows ? '.bat' : ''}',
    );
    if (candidate.existsSync()) return candidate.absolute.path;
  }
  throw ArgumentError('Flutter executable not found: $value');
}

void copySource(Directory source, Directory target) {
  target.createSync(recursive: true);
  for (final entity in source.listSync(followLinks: false)) {
    final name = entity.uri.pathSegments.where((s) => s.isNotEmpty).last;
    if ({
          '.git',
          '.dart_tool',
          'build',
          'coverage',
          'doc',
          '.DS_Store',
          '.flutter-plugins-dependencies',
        }.contains(name) ||
        (name == 'local' &&
            source.uri.pathSegments.where((s) => s.isNotEmpty).last ==
                'docs')) {
      continue;
    }
    final destination = '${target.path}/$name';
    if (entity is Directory) {
      copySource(entity, Directory(destination));
    } else if (entity is File) {
      entity.copySync(destination);
    } else if (entity is Link) {
      Link(destination).createSync(entity.targetSync());
    }
  }
}

List<VerifyStep> verificationSteps(
  String suite,
  String flutter,
  String root, {
  bool publishCheck = false,
}) {
  if (!{'full', 'minimum', 'router'}.contains(suite)) {
    throw ArgumentError('Unknown suite: $suite');
  }
  final dart =
      '${File(flutter).parent.path}/dart${Platform.isWindows ? '.bat' : ''}';
  final example = '$root/example';
  VerifyStep f(String name, List<String> args, [String? directory]) =>
      VerifyStep(name, flutter, args, directory ?? root);
  if (suite == 'router') {
    final directory = '$root/tool/compatibility/go_router_18';
    return [
      f('sdk', ['--version', '--machine']),
      f('router-get', ['pub', 'get'], directory),
      f('router-analyze', ['analyze'], directory),
      f('router-test', ['test', '--reporter', 'expanded'], directory),
    ];
  }
  return [
    f('sdk', ['--version', '--machine']),
    f('package-get', ['pub', 'get']),
    if (suite == 'full')
      VerifyStep('format', dart, [
        'format',
        '--output=none',
        '--set-exit-if-changed',
        'lib',
        'test',
        'example/lib',
        'example/test',
        if (Directory('$root/example/integration_test').existsSync())
          'example/integration_test',
        'tool',
      ], root),
    f('package-analyze', ['analyze']),
    if (suite == 'full') f('dependencies', ['pub', 'deps', '--style=compact']),
    f('package-test', [
      'test',
      '--enable-vmservice',
      '--reporter',
      'expanded',
      if (suite == 'full') ...[
        '--coverage',
        '--test-randomize-ordering-seed=20260713',
      ],
    ]),
    if (suite == 'full')
      VerifyStep('coverage', dart, [
        'tool/check_coverage.dart',
        'coverage/lcov.info',
      ], root),
    if (suite == 'full')
      VerifyStep('api-docs', dart, ['doc', '--dry-run'], root),
    f('example-get', ['pub', 'get'], example),
    f('example-analyze', ['analyze'], example),
    f('example-test', ['test', '--reporter', 'expanded'], example),
    if (suite == 'full') ...[
      f('web-showcase', ['build', 'web'], example),
      f('web-minimal', [
        'build',
        'web',
        '--target',
        'lib/minimal_main.dart',
      ], example),
      f('web-performance', [
        'build',
        'web',
        '--target',
        'lib/performance_main.dart',
      ], example),
      f('web-refresh', [
        'build',
        'web',
        '--target',
        'lib/refresh_lifecycle_main.dart',
      ], example),
    ],
    if (publishCheck) f('publish-dry-run', ['pub', 'publish', '--dry-run']),
  ];
}

Future<void> main(List<String> args) async {
  if (args.contains('--help')) {
    stdout.writeln(
      'dart tool/verify.dart [--suite full|minimum|router] [--flutter PATH]\n'
      '  [--output DIRECTORY] [--only STEP] [--keep-workspace] [--publish-check]\n'
      'Runs in an isolated copy including current changes. Never publishes.',
    );
    return;
  }
  String? value(String flag) {
    final index = args.indexOf(flag);
    if (index < 0) return null;
    if (index + 1 >= args.length || args[index + 1].startsWith('--')) {
      throw ArgumentError('Missing value for $flag');
    }
    return args[index + 1];
  }

  Directory? workspace;
  try {
    const values = {'--suite', '--flutter', '--output', '--only'};
    const flags = {'--keep-workspace', '--publish-check'};
    for (var i = 0; i < args.length; i++) {
      if (values.contains(args[i])) {
        value(args[i]);
        i++;
      } else if (!flags.contains(args[i])) {
        throw ArgumentError('Unknown option: ${args[i]}');
      }
    }
    final suite = value('--suite') ?? 'full';
    final flutter = resolveFlutter(value('--flutter') ?? 'flutter');
    final root = File.fromUri(Platform.script).parent.parent;
    final output =
        value('--output') == null
            ? Directory.systemTemp.createTempSync('super-overlay-verification-')
            : Directory(value('--output')!).absolute;
    if (suite != 'full' && args.contains('--publish-check')) {
      throw ArgumentError('--publish-check requires --suite full');
    }
    workspace = Directory.systemTemp.createTempSync('super-overlay-source-');
    copySource(root, workspace);
    var steps = verificationSteps(
      suite,
      flutter,
      workspace.path,
      publishCheck: args.contains('--publish-check'),
    );
    final only = value('--only');
    if (only != null) {
      steps =
          steps
              .where(
                (s) =>
                    s.name == 'sdk' ||
                    s.name.endsWith('-get') ||
                    (only == 'coverage' && s.name == 'package-test') ||
                    s.name == only,
              )
              .toList();
      if (!steps.any((s) => s.name == only)) {
        throw ArgumentError('Unknown step: $only');
      }
    }
    steps.insert(
      0,
      VerifyStep('patch-whitespace', 'git', ['diff', '--check'], root.path),
    );
    stdout.writeln('Workspace: ${workspace.path}');
    exitCode = await runSteps(
      steps,
      output,
      metadata: {
        'suite': suite,
        'flutter': flutter,
        'source': root.path,
        'workspace': workspace.path,
        'os': Platform.operatingSystemVersion,
        'dart': Platform.version,
        'seed': suite == 'full' ? 20260713 : null,
      },
    );
  } catch (error) {
    stderr.writeln(error);
    exitCode = 1;
  } finally {
    if (workspace != null && !args.contains('--keep-workspace')) {
      workspace.deleteSync(recursive: true);
    }
  }
}
