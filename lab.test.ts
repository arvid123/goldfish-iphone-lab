import { test, expect } from 'bun:test';
import { ReadTracker, textOf, replyText } from './lab';

test('read inference rejects absent, stale, future, and conflicting signals', () => {
  const t = new ReadTracker();
  expect(() => t.candidate()).toThrow();
  t.add('a@s.whatsapp.net', 'read', Date.now() - 60_000);
  t.add('a@s.whatsapp.net', 'read', Date.now() + 60_000);
  expect(() => t.candidate()).toThrow();
  t.add('a@s.whatsapp.net', 'read');
  expect(t.candidate().chat).toBe('a@s.whatsapp.net');
  expect(() => t.candidate(Date.now() + 31_000)).toThrow();
  t.add('b@s.whatsapp.net', 'read');
  expect(() => t.candidate()).toThrow('Several');
  t.reset();
  expect(() => t.candidate()).toThrow();
});

test('text extraction unwraps ephemeral messages but excludes view-once media', () => {
  expect(textOf({ message: { ephemeralMessage: { message: { conversation: 'hello' } } } })).toBe('hello');
  expect(textOf({ message: { viewOnceMessage: { message: { imageMessage: { caption: 'private' } } } } })).toBe('');
});

test('incomplete responses cannot overwrite user text', () => {
  const output = [{ content: [{ type: 'output_text', text: 'draft' }] }];
  expect(replyText({ status: 'completed', output })).toBe('draft');
  expect(() => replyText({ status: 'incomplete', output })).toThrow();
  expect(() => replyText({ output: [] })).toThrow();
});
