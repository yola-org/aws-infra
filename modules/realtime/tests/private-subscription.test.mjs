import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
import test from 'node:test';

// Exercise the shipped handler; replace only the AppSync runtime import.
// This checks access decisions locally, not AWS runtime compatibility.
const source = await readFile(new URL('../handlers/private-subscription.js', import.meta.url), 'utf8');
const stubbed = source.replace(
  "import { util } from '@aws-appsync/utils';",
  "const util = { unauthorized() { throw new Error('Unauthorized'); } };",
);
const { onSubscribe } = await import('data:text/javascript;base64,' + Buffer.from(stubbed).toString('base64'));

for (const namespace of ['chat', 'notifications']) {
  const context = (path, identity = { sub: 'user-123' }) => ({
    identity,
    info: { channel: { path }, channelNamespace: { name: namespace } },
  });

  test(`${namespace}: accepts only the authenticated user's exact channel`, () => {
    assert.doesNotThrow(() => onSubscribe(context(`/${namespace}/user-123`)));
    for (const path of [
      `/${namespace}/other-user`, `/${namespace}/*`, `/${namespace}`,
      `/${namespace}/user-123/*`, `/${namespace}/user-123/extra`,
      `/${namespace}/user-123/`, `/${namespace}/user-1234`,
      '/other/user-123',
    ]) {
      assert.throws(() => onSubscribe(context(path)), /Unauthorized/);
    }
  });

  test(`${namespace}: rejects missing and non-Cognito identities`, () => {
    for (const identity of [null, {}, { userArn: 'arn:aws:iam::123456789012:user/test' }, { sub: '' }]) {
      assert.throws(() => onSubscribe(context(`/${namespace}/user-123`, identity)), /Unauthorized/);
    }
  });
}
