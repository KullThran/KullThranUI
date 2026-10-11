"""Minimal Lua 5.1 tokenizer used by locale_check.py: strings, names, numbers and operators; comments dropped."""
import re
def lex(src):
    """Yield (kind, value, line) for a Lua source: kinds 'str','name','op'. Comments dropped."""
    i, n, line = 0, len(src), 1
    toks = []
    while i < n:
        c = src[i]
        if c == '\n': line += 1; i += 1; continue
        if c in ' \t\r\f\v': i += 1; continue
        if src.startswith('--', i):
            m = re.match(r'--\[(=*)\[', src[i:])
            if m:
                close = ']' + m.group(1) + ']'
                j = src.find(close, i)
                j = n if j < 0 else j + len(close)
                line += src.count('\n', i, j); i = j; continue
            j = src.find('\n', i); i = n if j < 0 else j; continue
        m = re.match(r'\[(=*)\[', src[i:i+20]) if c == '[' else None
        if m:
            close = ']' + m.group(1) + ']'
            j = src.find(close, i)
            if j < 0: j = n
            val = src[i+len(m.group(0)):j]
            if val.startswith('\r\n'): val = val[2:]
            elif val.startswith('\n'): val = val[1:]
            toks.append(('str', val, line))
            line += src.count('\n', i, j); i = j + len(close); continue
        if c in '"\'':
            j = i + 1; buf = []; start = line
            while j < n and src[j] != c:
                if src[j] == '\\' and j + 1 < n:
                    e = src[j+1]
                    mp = {'n':'\n','t':'\t','r':'\r','\\':'\\','"':'"',"'":"'",'a':'\a','b':'\b','f':'\f','v':'\v'}
                    if e in mp: buf.append(mp[e]); j += 2; continue
                    if e == '\n': buf.append('\n'); line += 1; j += 2; continue
                    if e == '\r':
                        buf.append('\n'); j += 2
                        if j < n and src[j] == '\n': j += 1
                        line += 1; continue
                    md = re.match(r'\d{1,3}', src[j+1:j+4])
                    if md: buf.append(chr(int(md.group(0)))); j += 1 + len(md.group(0)); continue
                    buf.append(e); j += 2; continue
                if src[j] == '\n': break
                buf.append(src[j]); j += 1
            val = ''.join(buf)
            # Lua 5.1 \ddd escapes are bytes; re-decode utf-8 sequences
            try: val = val.encode('latin-1').decode('utf-8')
            except Exception: pass
            toks.append(('str', val, start)); i = j + 1; continue
        m = re.match(r'[A-Za-z_][A-Za-z0-9_]*', src[i:i+200])
        if m: toks.append(('name', m.group(0), line)); i += len(m.group(0)); continue
        m = re.match(r'0[xX][0-9a-fA-F]+|\d+\.?\d*(?:[eE][+-]?\d+)?|\.\d+', src[i:i+100])
        if m: toks.append(('num', m.group(0), line)); i += len(m.group(0)); continue
        m = re.match(r'\.\.\.|\.\.|==|~=|<=|>=|.', src[i:i+3], re.S)
        toks.append(('op', m.group(0), line)); i += len(m.group(0))
    return toks
