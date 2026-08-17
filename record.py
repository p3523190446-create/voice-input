# -*- coding: utf-8 -*-
import sys, wave, time, os
import numpy as np
import sounddevice as sd

SR = 16000
BLOCK = int(SR * 0.2)
FALLBACK_SILENCE_LIMIT = 15
MIN_BLOCKS = 3
MAX_BLOCKS = 600
RMS_THRESHOLD = 300

def main():
    args = sys.argv[1:]
    out = args[0] if args else os.path.join(os.environ.get('TEMP', '.'), 'voice-input.wav')
    flag = None
    device = None
    i = 1
    while i < len(args):
        if args[i] == '--flag' and i + 1 < len(args):
            flag = args[i + 1]; i += 2
        elif args[i] == '--device' and i + 1 < len(args):
            try: device = int(args[i + 1])
            except ValueError: pass
            i += 2
        else:
            i += 1
    blocks = []
    silence_blocks = 0
    start = time.time()
    try:
        kwargs = dict(samplerate=SR, channels=1, dtype='int16', blocksize=BLOCK)
        if device is not None:
            kwargs['device'] = device
        with sd.InputStream(**kwargs) as stream:
            while True:
                data, overflowed = stream.read(BLOCK)
                blocks.append(np.array(data, copy=True).reshape(-1))
                rms = float(np.sqrt(np.mean(blocks[-1].astype(np.float32) ** 2)))
                if rms < RMS_THRESHOLD:
                    silence_blocks += 1
                else:
                    silence_blocks = 0
                if flag and os.path.exists(flag):
                    break
                if len(blocks) >= MIN_BLOCKS and silence_blocks >= FALLBACK_SILENCE_LIMIT:
                    break
                if len(blocks) >= MAX_BLOCKS:
                    break
                if time.time() - start > 125:
                    break
    except Exception as e:
        sys.stderr.write('ERR:' + str(e) + '\n')
        sys.exit(1)

    audio = np.concatenate(blocks) if blocks else np.zeros(0, dtype=np.int16)
    if len(audio) > 0:
        idx = np.where(np.abs(audio.astype(np.float32)) > RMS_THRESHOLD * 0.8)[0]
        if len(idx) > 0:
            audio = audio[max(0, idx[0] - BLOCK): min(len(audio), idx[-1] + BLOCK)]
    with wave.open(out, 'wb') as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(audio.tobytes())
    sys.stdout.write('OK:' + out + '\n')

if __name__ == '__main__':
    main()