import 'dart:async';
import 'dart:io';

import 'package:vm_service/vm_service.dart';
import 'package:vm_service/vm_service_io.dart';


Future<void> main(List<String> args) async {
  if (args.isEmpty) {
    print('Usage: dart script.dart <observatory-uri>');
    exit(1);
  }

  final observatoryUriHttp= args[0];
  final observatoryUri = convertToWebSocketUrl(observatoryUriHttp);
  print("Connecting to $observatoryUri");

  final service = await vmServiceConnectUri(observatoryUri);
  print('Connected to VM service');

  service.onIsolateEvent.listen((event) async {
    if (event.kind == EventKind.kIsolateRunnable) {
      print('New isolate detected. Setting breakpoints...');
      await setTestBreakpoints(service, event.isolate!.id!);
    }
  });

  service.onDebugEvent.listen((event) {
    if (event.kind == EventKind.kPauseBreakpoint) {
      handleBreakpoint(service, event);
    }
  });

  await service.streamListen(EventStreams.kDebug);
  await service.streamListen(EventStreams.kIsolate);

  print('Listening for events...');
  
  // Set initial breakpoints
  final vm = await service.getVM();
  for (final isolateRef in vm.isolates!) {
    await setTestBreakpoints(service, isolateRef.id!);
  }
}

Future<void> setTestBreakpoints(VmService service, String isolateId) async {
  final scripts = await service.getScripts(isolateId);

  for (final scriptRef in scripts.scripts!) {
    if (scriptRef.uri!.contains('_test.dart')) {
      print('Setting breakpoints in ${scriptRef.uri}');
      final script = await service.getObject(isolateId, scriptRef.id!) as Script;
      final lines = script.source!.split('\n');

      for (int i = 0; i < lines.length; i++) {
        if (lines[i].trim().startsWith('test(') || 
            lines[i].trim().startsWith('testWidgets(') ||
            lines[i].trim().startsWith('patrol(')) {
          // Find the end of the test function
          int endLine = findTestFunctionEnd(lines, i);
          print('Found test starting at line ${i + 1} and ending at line ${endLine + 1}');
          if (endLine != -1) {
            try {
              final bp = await service.addBreakpointWithScriptUri(
                isolateId, 
                scriptRef.uri!, 
                endLine,
              );
              print('Breakpoint added: ${bp.id} at line $endLine (end of test)');
            } catch (e) {
              print('Error adding breakpoint: $e');
            }
          } else {
            print('Could not find end of test starting at line ${i + 1}');
          }
        }
      }
    }
  }
}

int findTestFunctionEnd(List<String> lines, int startLine) {
  int bracketCount = 0;
  bool foundOpeningBracket = false;
  for (int i = startLine; i < lines.length; i++) {
    if (!foundOpeningBracket && lines[i].contains('{')) {
      foundOpeningBracket = true;
    }
    if (foundOpeningBracket) {
      bracketCount += '{'.allMatches(lines[i]).length;
      bracketCount -= '}'.allMatches(lines[i]).length;
      if (bracketCount == 0) {
        return i;  // Return the line with the closing bracket
      }
    }
  }
  return -1;  // End not found
}


void handleBreakpoint(VmService service, Event event) async {
  if (event.isolate?.id == null) {
    print('Warning: Isolate ID is null');
    return;
  }
  final isolateId = event.isolate!.id!;

  print('Breakpoint hit in isolate: $isolateId');

  // Safely get the breakpoint ID
  final breakpointId = event.breakpoint?.id ?? 'Unknown';
  print('Breakpoint ID: $breakpointId');

  try {
    // Safely get the script information
    if (event.topFrame?.location?.script == null) {
      print('Warning: Script information is not available');
    } else {
      final scriptRef = event.topFrame!.location!.script!;
      final script = await service.getObject(isolateId, scriptRef.id!) as Script?;
      
      if (script != null) {
        final lineNumber = event.topFrame?.location?.line ?? 'Unknown';
        print('Paused at ${script.uri}:$lineNumber (end of test)');
      } else {
        print('Warning: Unable to retrieve script information');
      }
    }

    // Get the current stack trace
    final stack = await service.getStack(isolateId);
    if (stack.frames != null && stack.frames!.isNotEmpty) {
      print('Current stack trace:');
      for (var frame in stack.frames!.take(5)) { // Print top 5 frames
        print('  ${frame.function?.name ?? 'Unknown'} at ${frame.location?.script?.uri}:${frame.location?.line}');
      }
    } else {
      print('Warning: Stack trace is not available');
    }

    print('Execution paused. Waiting for 10 seconds...');
    
    // Wait for 10 seconds
    await Future.delayed(Duration(seconds: 10));

    // Resume the isolate
    await service.resume(isolateId);
    print('Resumed execution after 10 seconds pause');
  } catch (e) {
    print('Error handling breakpoint: $e');
  }
}

String convertToWebSocketUrl(String observatoryUri) {
  observatoryUri = observatoryUri.replaceFirst('http://', 'ws://');
  if (!observatoryUri.endsWith('/ws')) {
    observatoryUri += 'ws';
  }
  return observatoryUri;
}
