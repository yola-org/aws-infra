import { util } from '@aws-appsync/utils';

// Exact equality rejects wildcards, other users, and additional path segments.
// The namespace's auth mode guarantees that identity is a Cognito identity.
export function onSubscribe(ctx) {
  if (!ctx.identity || !ctx.identity.sub) {
    util.unauthorized();
    return;
  }

  const allowed = '/' + ctx.info.channelNamespace.name + '/' + ctx.identity.sub;
  if (ctx.info.channel.path !== allowed) {
    util.unauthorized();
  }
}
