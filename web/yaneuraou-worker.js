// web/yaneuraou-worker.js — YaneuraOu WASM USI エンジン Worker
// @mizarjp/yaneuraou.halfkp を CDN から読み込み、USI プロトコルで通信する
'use strict';

const CDN_BASE = 'https://cdn.jsdelivr.net/npm/@mizarjp/yaneuraou.halfkp/src/';
const ENGINE_JS  = CDN_BASE + 'yaneuraou.halfkp.js';

let inputBuffer = '';   // 未処理の stdin 文字列
let engineReady = false;

// --- エンジン出力ハンドラ ---
function handleOutput(line) {
  // メインスレッドに生ラインを転送（デバッグ用）
  // self.postMessage({ type: 'log', line });

  if (line === 'usiok') {
    // オプション設定後に isready を送る
    pushInput('setoption name USI_Ponder value false\n');
    pushInput('setoption name Threads value 1\n');
    pushInput('isready\n');
  } else if (line === 'readyok') {
    engineReady = true;
    self.postMessage({ type: 'ready' });
  } else if (line.startsWith('bestmove ')) {
    const parts = line.split(' ');
    const move = parts[1]; // "7g7f", "G*5e", "resign", "win"
    const isValid = move && move !== 'resign' && move !== 'win';
    self.postMessage({ type: 'bestmove', move: isValid ? move : null });
  } else if (line.startsWith('info ')) {
    // 思考情報（省略可）
  }
}

// stdin キューに文字列を追加
function pushInput(text) {
  inputBuffer += text;
}

// --- エンジン読み込み ---
try {
  importScripts(ENGINE_JS);

  const factory = self.YaneuraOuModule || self.Module;
  if (typeof factory !== 'function') {
    throw new Error('YaneuraOuModule not found after importScripts');
  }

  factory({
    // WASM ファイルを CDN から取得するよう override
    locateFile: (path) => CDN_BASE + path,

    // stdout → handleOutput
    print: handleOutput,

    // stderr → 抑制
    printErr: (_) => {},

    // stdin → inputBuffer から 1 文字ずつ返す
    stdin: () => {
      if (inputBuffer.length > 0) {
        const code = inputBuffer.charCodeAt(0);
        inputBuffer = inputBuffer.slice(1);
        return code;
      }
      // データなし → null/-1 を返す（エンジンは再度呼び出す）
      return -1;
    },
  }).then(() => {
    // エンジン起動 → USI ハンドシェイク開始
    pushInput('usi\n');
  }).catch((err) => {
    self.postMessage({ type: 'error', message: String(err) });
  });

} catch (err) {
  self.postMessage({ type: 'error', message: String(err) });
}

// --- メインスレッドからのメッセージ ---
self.onmessage = function (e) {
  const msg = e.data;
  if (!msg || !msg.type) return;

  switch (msg.type) {
    case 'go':
      if (!engineReady) {
        self.postMessage({ type: 'error', message: 'Engine not ready' });
        return;
      }
      pushInput('position sfen ' + msg.sfen + '\n');
      pushInput('go byoyomi ' + (msg.byoyomi || 3000) + '\n');
      break;

    case 'stop':
      pushInput('stop\n');
      break;

    case 'quit':
      pushInput('quit\n');
      break;
  }
};
