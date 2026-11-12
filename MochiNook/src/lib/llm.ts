import * as Device from 'expo-device';
import * as Network from 'expo-network';
import RNBlobUtil from 'react-native-blob-util';
import { parseSteps } from './parseSteps';
import {
  createLLMChatSession,
  download,
  models,
  setTelemetryEnabled,
  type LLMChatSession,
  type LLMModel,
} from 'react-native-executorch';

/**
 * Pro feature: a tiny language model that runs 100% on the phone.
 *
 * Lifecycle (battery + RAM friendly):
 *  1. Downloaded only after Pro unlock, only when the user taps download.
 *  2. Never kept in memory. `withSession` loads it for one request and
 *     disposes it in `finally`, right after the result is returned.
 */

export const MODEL_LABEL = 'Qwen 2.5 · 0.5B (quantized)';
const MODEL: LLMModel = models.llm.QWEN2_5_0_5B.DEFAULT;

/** Phones sold as "4 GB" report a little less because the system reserves some memory. */
const MIN_RAM_BYTES = 3.5 * 1024 ** 3;

// Keep everything private: no anonymous download pings.
setTelemetryEnabled(false);

export function deviceRamBytes(): number | null {
  return Device.totalMemory;
}

export function hasEnoughRam(): boolean {
  const ram = Device.totalMemory;
  return ram !== null && ram >= MIN_RAM_BYTES;
}

export type ConnectionKind = 'wifi' | 'cellular' | 'offline' | 'other';

export async function connectionKind(): Promise<ConnectionKind> {
  const state = await Network.getNetworkStateAsync();
  if (!state.isConnected || state.isInternetReachable === false) return 'offline';
  if (state.type === Network.NetworkStateType.WIFI || state.type === Network.NetworkStateType.ETHERNET) return 'wifi';
  if (state.type === Network.NetworkStateType.CELLULAR) return 'cellular';
  return 'other';
}

// ---------- download (shared state so progress survives leaving the screen) ----------

export type DownloadState =
  | { status: 'idle' }
  | { status: 'downloading'; progress: number }
  | { status: 'ready' }
  | { status: 'error'; message: string };

let state: DownloadState = { status: 'idle' };
let controller: AbortController | null = null;
const listeners = new Set<(s: DownloadState) => void>();

function setState(next: DownloadState): void {
  state = next;
  listeners.forEach((l) => l(next));
}

export function getDownloadState(): DownloadState {
  return state;
}

export function subscribeDownload(listener: (s: DownloadState) => void): () => void {
  listeners.add(listener);
  return () => {
    listeners.delete(listener);
  };
}

export function parseStoredPaths(json: string | null): LLMModel | null {
  if (!json) return null;
  try {
    const p = JSON.parse(json) as Partial<LLMModel>;
    if (typeof p.modelPath === 'string' && typeof p.tokenizerPath === 'string' && typeof p.tokenizerConfigPath === 'string') {
      return { modelPath: p.modelPath, tokenizerPath: p.tokenizerPath, tokenizerConfigPath: p.tokenizerConfigPath };
    }
  } catch {
    // fall through
  }
  return null;
}

/** True if the stored local files still exist on disk. */
export async function modelFilesPresent(local: LLMModel | null): Promise<boolean> {
  if (!local) return false;
  const paths = [local.modelPath, local.tokenizerPath, local.tokenizerConfigPath].map((p) => p.replace(/^file:\/\//, ''));
  const checks = await Promise.all(paths.map((p) => RNBlobUtil.fs.exists(p).catch(() => false)));
  return checks.every(Boolean);
}

/** Downloads (or resumes) the model. Resolves with the local paths as JSON for storage. */
export async function downloadModel(): Promise<string | null> {
  if (state.status === 'downloading') return null;
  controller = new AbortController();
  setState({ status: 'downloading', progress: 0 });
  try {
    const local = await download(MODEL, {
      signal: controller.signal,
      onProgress: (p) => setState({ status: 'downloading', progress: Math.max(0, Math.min(1, p)) }),
    });
    setState({ status: 'ready' });
    return JSON.stringify({
      modelPath: local.modelPath,
      tokenizerPath: local.tokenizerPath,
      tokenizerConfigPath: local.tokenizerConfigPath,
    });
  } catch (e) {
    if (controller?.signal.aborted) {
      setState({ status: 'idle' });
    } else {
      setState({ status: 'error', message: e instanceof Error ? e.message : 'The download stopped.' });
    }
    return null;
  } finally {
    controller = null;
  }
}

export function cancelDownload(): void {
  controller?.abort();
}

export async function deleteModelFiles(local: LLMModel | null): Promise<void> {
  if (local) {
    const paths = [local.modelPath, local.tokenizerPath, local.tokenizerConfigPath].map((p) => p.replace(/^file:\/\//, ''));
    await Promise.all(paths.map((p) => RNBlobUtil.fs.unlink(p).catch(() => undefined)));
  }
  setState({ status: 'idle' });
}

export function markReady(): void {
  if (state.status !== 'downloading') setState({ status: 'ready' });
}

// ---------- inference ----------

let busy = false;

async function withSession<T>(local: LLMModel, system: string, run: (s: LLMChatSession) => Promise<T>): Promise<T> {
  if (busy) throw new Error('Your pet is still thinking about the last one.');
  busy = true;
  let session: LLMChatSession | null = null;
  try {
    session = await createLLMChatSession(local, {
      initialMessages: [{ role: 'system', content: system }],
      generationConfig: { temperature: 0.3, topP: 0.9, maxNewTokens: 220 },
    });
    return await run(session);
  } finally {
    // Release model weights, KV cache and tokenizer immediately.
    session?.dispose();
    busy = false;
  }
}

function lastAssistantText(messages: readonly { role: string; content?: unknown }[]): string {
  for (let i = messages.length - 1; i >= 0; i--) {
    const m = messages[i];
    if (m && m.role === 'assistant' && typeof m.content === 'string') return m.content;
  }
  return '';
}

const BREAKDOWN_SYSTEM =
  'You help people with ADHD and autism start tasks. Break the user\'s task into 4 to 6 tiny, literal, physical steps. ' +
  'Each step is one short sentence that starts with a verb, takes under 5 minutes, and says exactly what to touch or do. ' +
  'No pressure words like "must" or "now". Reply ONLY with a numbered list, one step per line.';

const SOFTEN_SYSTEM =
  'Rewrite the user\'s to-do as one gentle, low-pressure invitation, written as a friendly question that offers to do it together. ' +
  'Never use "must", "now", "should" or "have to". Under 20 words. Reply with the sentence only.';

export async function breakDownWithModel(local: LLMModel, task: string): Promise<string[]> {
  return withSession(local, BREAKDOWN_SYSTEM, async (session) => {
    const turn = await session.sendMessage(task.slice(0, 400));
    return parseSteps(lastAssistantText(turn.messages));
  });
}

export async function softenWithModel(local: LLMModel, text: string): Promise<string> {
  return withSession(local, SOFTEN_SYSTEM, async (session) => {
    const turn = await session.sendMessage(text.slice(0, 300));
    return lastAssistantText(turn.messages).split(/\r?\n/)[0]?.replace(/^["']|["']$/g, '').trim() ?? '';
  });
}
