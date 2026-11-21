// Compile this same predicate in the observer and in its synthetic metadata checks.
export const windowPredicateSource = `import AppKit
import CoreGraphics
func hasRegularOnScreenWindow(pid: Int, regular: Bool, windows: (CGWindowListOption) -> [[String:Any]]) -> Bool {
  regular && windows(.optionOnScreenOnly).contains {
    ($0[kCGWindowOwnerPID as String] as? Int) == pid && ($0[kCGWindowLayer as String] as? Int) == 0
  }
}
`;

const windowProbe = windowPredicateSource + `
let deadline = Date(timeIntervalSince1970: Double(CommandLine.arguments[1])! / 1000)
// Warm the query boundaries before launch, rather than just starting Swift early.
_ = NSRunningApplication.current.activationPolicy
_ = CGWindowListCopyWindowInfo(.optionOnScreenOnly, kCGNullWindowID)
guard Date() < deadline else { fputs("native-window-deadline\\n", stderr); exit(1) }
print("native-window-ready"); fflush(stdout)
guard let input = readLine(), let pid = Int(input), pid > 0, pid <= Int(Int32.max), Date() < deadline else {
  fputs("native-window-invalid-target-or-deadline\\n", stderr); exit(1)
}
var previous = ""
while Date() < deadline {
  let app = NSRunningApplication(processIdentifier: pid_t(pid))
  let regular = app?.activationPolicy == .regular
  let found = hasRegularOnScreenWindow(pid: pid, regular: regular) {
    CGWindowListCopyWindowInfo($0, kCGNullWindowID) as? [[String:Any]] ?? []
  }
  let state = "regular=\\(regular) matched=\\(found) registered=\\(app != nil) terminated=\\(app?.isTerminated ?? false)\\n"
  if state != previous { fputs(state, stderr); previous = state }
  if found { print("native-window-observed:\\(pid)"); fflush(stdout); exit(0) }
  if app?.isTerminated == true { exit(1) }
  RunLoop.current.run(until: min(deadline, Date().addingTimeInterval(0.025)))
}
fputs("native-window-deadline\\n", stderr); exit(1)`;

export async function launchObservedNative({lifecycle, launch, cwd, env, deadline}) {
  let observer, native, timer, failure, primary, cleanupError;
  let phase='starting', buffer='', bytes=0;
  const ready=Promise.withResolvers(), observed=Promise.withResolvers(), detach=[];
  // A synchronous stream event can reject before the next await is installed.
  ready.promise.catch(()=>{}); observed.promise.catch(()=>{});
  function fail(error) {
    failure ??= error;
    ready.reject(failure); observed.reject(failure);
  }
  function listen(target,event,callback) {
    target.on(event,callback);
    detach.push(()=>target.removeListener(event,callback));
  }
  function requireTime() {
    if (!Number.isFinite(deadline) || Date.now()>=deadline) throw new Error('Native window observation deadline exceeded');
  }
  function requireLiveNative() {
    if (native.child.exitCode!==null || native.child.signalCode!==null) throw new Error('Native child exited before window observation completed');
  }
  function consume(data) {
    if (failure) return;
    bytes+=Buffer.byteLength(data);
    if (bytes>8192) return fail(new Error('Native window protocol exceeds 8 KiB'));
    buffer+=data;
    let newline;
    while ((newline=buffer.indexOf('\n'))>=0) {
      const line=buffer.slice(0,newline); buffer=buffer.slice(newline+1);
      if (line==='native-window-ready' && phase==='starting') {
        phase='ready'; ready.resolve();
      } else if (native && line==='native-window-observed:'+native.child.pid && phase==='observing') {
        phase='observed';
      } else return fail(new Error('Invalid native window protocol'));
    }
  }
  try {
    requireTime();
    timer=setTimeout(()=>fail(new Error('Native window observation deadline exceeded')),deadline-Date.now());
    observer=lifecycle.start('/usr/bin/swift',['-e',windowProbe,String(deadline)],{cwd,env,detached:true});
    listen(observer.child,'error',fail);
    for (const stream of [observer.child.stdin,observer.child.stdout,observer.child.stderr]) listen(stream,'error',fail);
    listen(observer.child.stdout,'data',consume);
    observer.closed.then(([code,signal])=>{
      if (code!==0 || signal!==null) return fail(new Error('Native window observer exited unsuccessfully: '+code+'/'+signal));
      if (phase!=='observed' || buffer) return fail(new Error('Native window observer exited without a valid observation'));
      try { requireTime(); requireLiveNative(); observed.resolve(); } catch (error) { fail(error); }
    },fail);
    // lifecycle.start may already have captured a readiness frame before return.
    consume(observer.stdout);
    await ready.promise;
    if (failure) throw failure;
    requireTime();
    if (observer.child.exitCode!==null || observer.child.signalCode!==null) throw new Error('Native window observer exited before app launch');
    native=launch();
    listen(native.child,'exit',()=>fail(new Error('Native child exited during window observation')));
    listen(native.child,'error',fail);
    native.closed.catch(fail);
    requireLiveNative(); requireTime();
    if (!Number.isSafeInteger(native.child.pid) || native.child.pid<=0) throw new Error('Invalid native child PID');
    phase='observing';
    observer.child.stdin.end(String(native.child.pid)+'\n');
    await observed.promise;
    if (failure) throw failure;
  } catch (error) { primary=error; }
  finally {
    clearTimeout(timer);
    try { if (observer) await lifecycle.stop(observer); }
    catch (error) { cleanupError=error; }
    for (const remove of detach) remove();
  }
  primary ??= failure;
  if (primary) {
    const details={};
    for (const [name,tracked] of [['native',native],['observer',observer]]) if (tracked) {
      details[name]={exitCode:tracked.child.exitCode,signalCode:tracked.child.signalCode,
        stdout:tracked.stdout.slice(-4096),stderr:tracked.stderr.slice(-4096)};
    }
    primary=new Error('Native window observation failed: '+primary.message.slice(0,4096)+' '+JSON.stringify(details),{cause:primary});
  }
  if (cleanupError && primary) throw new AggregateError([primary,cleanupError],'Native window observation and cleanup failed');
  if (cleanupError) throw cleanupError;
  if (primary) throw primary;
  return native;
}
