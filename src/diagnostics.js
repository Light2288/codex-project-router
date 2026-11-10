import { UUID } from './config.js';
import { RouterError } from './errors.js';
export function emitDiagnostic(stream, event) {
  const record={timestamp:new Date().toISOString(),event:['started','completed','rejected'].includes(event.event)?event.event:'rejected'};
  for (const key of ['requestId','threadId','ownerThreadId','projectId']) if (typeof event[key] === 'string' && UUID.test(event[key])) record[key]=event[key];
  if (typeof event.routeAlias === 'string' && /^[a-zA-Z0-9][a-zA-Z0-9_-]{0,63}$/.test(event.routeAlias)) record.routeAlias=event.routeAlias;
  if (['direct','ancestor','catalog'].includes(event.source)) record.source=event.source;
  if (Number.isInteger(event.status) && event.status >= 100 && event.status <= 599) record.status=event.status;
  if (Number.isFinite(event.elapsedMs) && event.elapsedMs >= 0) record.elapsedMs=event.elapsedMs;
  if (event.errorCode !== undefined) record.errorCode=new RouterError(event.errorCode).code;
  return stream.write(JSON.stringify(record)+'\n');
}
