"""章の下書きに、記録から作ったブロックを差し込む。<!-- KEY_BLOCK --> を初回に置き換え、2回目からは
<!-- gen:KEY --> … <!-- /gen:KEY --> の間を作り直す（記録を取り直したら、もう一度走らせるだけでよい）。"""
import pathlib as _pl, sys as _sys
_HERE = _pl.Path(__file__).resolve().parent
REPO = _HERE.parent.parent
_sys.path.insert(0, str(_HERE))

import re

def apply(path, blocks):
    s = open(path, encoding='utf-8').read()
    for key, content in blocks.items():
        ph = f'<!-- {key}_BLOCK -->'
        body = f'<!-- gen:{key} -->\n{content}\n<!-- /gen:{key} -->'
        if ph in s:
            assert s.count(ph) == 1, ph
            s = s.replace(ph, body)
        else:
            pat = re.compile(rf'<!-- gen:{key} -->\n.*?\n<!-- /gen:{key} -->', re.S)
            assert len(pat.findall(s)) == 1, key
            s = pat.sub(lambda m: body, s)
    open(path, 'w', encoding='utf-8').write(s)
