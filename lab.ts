export type Signal = { chat: string; at: number; kind: string };

// This records recent reads, not a verified foreground-chat identity.
export class ReadTracker {
  signals: Signal[] = [];
  add(chat: string, kind: string, at = Date.now()) {
    if (!chat || chat.endsWith('@broadcast') || !Number.isFinite(at)) return;
    const now = Date.now();
    if (at < now - 30_000 || at > now + 5_000) return;
    this.signals.push({ chat, kind, at });
    this.signals = this.signals.filter(s => s.at >= now - 30_000).slice(-80);
  }
  candidate(now = Date.now()) {
    const fresh = this.signals.filter(s => s.at >= now - 30_000 && s.at <= now + 5_000);
    const latest = fresh.reduce<Signal | null>((last, s) => !last || s.at >= last.at ? s : last, null);
    if (!latest) throw new Error('No fresh WhatsApp read signal. Open a conversation with a new unread message and try again.');
    if (fresh.some(s => s.chat !== latest.chat && s.at >= latest.at - 3_000)) {
      throw new Error('Several conversations changed together. Cannot identify one conversation.');
    }
    return latest;
  }
  reset() { this.signals = []; }
}

export function textOf(raw: any): string {
  let m = raw?.message;
  for (let i = 0; i < 4; i++) {
    // View-once content deliberately isn't ingested into this prototype.
    if (m?.viewOnceMessage || m?.viewOnceMessageV2) return '';
    const nested = m?.ephemeralMessage?.message || m?.documentWithCaptionMessage?.message;
    if (!nested) break;
    m = nested;
  }
  return String(m?.conversation || m?.extendedTextMessage?.text || m?.imageMessage?.caption || m?.videoMessage?.caption || '').slice(0, 8000);
}

export function replyText(response: any): string {
  const result = (response.output || []).flatMap((o: any) => o.content || [])
    .filter((c: any) => c.type === 'output_text').map((c: any) => c.text).join('').trim();
  if (!result || response.status === 'incomplete') throw new Error('Goldfish did not return a complete draft.');
  return result;
}
