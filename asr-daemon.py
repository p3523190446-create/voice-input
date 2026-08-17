# -*- coding: utf-8 -*-
# 语音识别引擎（常驻）：模型加载一次，通过 request.txt / result.txt 与主控通信
import os, sys, time, json, ctypes
from faster_whisper import WhisperModel
from opencc import OpenCC
import cn2an

TOOL_DIR = os.path.dirname(os.path.abspath(__file__))
SETTINGS = os.path.join(TOOL_DIR, 'settings.json')
HISTORY = os.path.join(TOOL_DIR, 'history.txt')
WORKDIR = sys.argv[1] if len(sys.argv) > 1 else os.getcwd()
REQUEST = os.path.join(WORKDIR, 'request.txt')
RESULT = os.path.join(WORKDIR, 'result.txt')
READY = os.path.join(WORKDIR, 'ready.txt')

PROCESS_QUERY_LIMITED_INFORMATION = 0x1000
STILL_ACTIVE = 259

def load_settings():
    try:
        with open(SETTINGS, 'r', encoding='utf-8') as f:
            return json.load(f)
    except Exception:
        return {}

def get_model_map():
    s = load_settings()
    base = (s.get('modelsDir') or os.environ.get('VOICEINPUT_MODELS_DIR')
            or os.path.join(os.path.expanduser('~'), 'AppData', 'Local', 'WhisperModels'))
    return {
        'small': os.path.join(base, 'small'),
        'large-v3-turbo': os.path.join(base, 'large-v3-turbo'),
    }

def parent_alive(pid):
    if pid <= 0:
        return True
    try:
        h = ctypes.windll.kernel32.OpenProcess(PROCESS_QUERY_LIMITED_INFORMATION, False, pid)
        if not h:
            return False
        code = ctypes.c_ulong()
        ctypes.windll.kernel32.GetExitCodeProcess(h, ctypes.byref(code))
        ctypes.windll.kernel32.CloseHandle(h)
        return code.value == STILL_ACTIVE
    except Exception:
        return True

def post_process(text, settings):
    if settings.get('smartPunct', True):
        try:
            text = cn2an.transform(text)
        except Exception:
            pass
    return text

def main():
    parent_pid = os.getppid()
    os.environ['HF_HUB_OFFLINE'] = '1'
    settings = load_settings()
    model_key = settings.get('model', 'small')
    model_map = get_model_map()
    if model_key not in model_map:
        model_key = 'small'
    model = WhisperModel(model_map[model_key], device='cpu', compute_type='int8')
    cc = OpenCC('t2s')
    with open(READY, 'w', encoding='utf-8') as f:
        f.write('ready')
    last_check = time.time()
    while True:
        settings = load_settings()
        lang = settings.get('language', 'auto')
        if lang not in ('zh', 'en', 'auto'):
            lang = 'auto'
        hotwords = (settings.get('vocab') or '').strip()
        if os.path.exists(REQUEST):
            wav = ''
            try:
                with open(REQUEST, 'r', encoding='utf-8') as f:
                    wav = f.read().strip()
                try:
                    os.remove(REQUEST)
                except OSError:
                    pass
                if wav and os.path.exists(wav):
                    t_kwargs = dict(beam_size=1, vad_filter=True, condition_on_previous_text=False)
                    if lang == 'auto':
                        t_kwargs['language'] = None
                    else:
                        t_kwargs['language'] = lang
                    if hotwords:
                        t_kwargs['hotwords'] = hotwords
                    segments, info = model.transcribe(wav, **t_kwargs)
                    text = ''.join(s.text for s in segments).strip()
                    text = cc.convert(text)
                    text = post_process(text, settings)
                else:
                    text = ''
                with open(RESULT, 'w', encoding='utf-8') as f:
                    f.write(text)
                if text:
                    try:
                        with open(HISTORY, 'a', encoding='utf-8') as f:
                            f.write(time.strftime('%Y-%m-%d %H:%M:%S') + '\t' + text + '\n')
                    except Exception:
                        pass
            except Exception as e:
                try:
                    with open(RESULT, 'w', encoding='utf-8') as f:
                        f.write('ERR:' + str(e))
                except Exception:
                    pass
            time.sleep(0.02)
        now = time.time()
        if now - last_check > 2:
            last_check = now
            if not parent_alive(parent_pid):
                break
        time.sleep(0.02)

if __name__ == '__main__':
    main()