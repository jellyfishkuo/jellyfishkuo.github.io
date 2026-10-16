"""產生 research/benchmark.html：把 algos.js（Web Worker 裡跑的演算法）整段塞進 benchmark.html.tpl

用法（和其他 Demo 一樣）：cd tools/research/benchmark && python3 -B build.py ../../../research/code
這頁沒有要下載的程式碼檔，research/code/ 這個參數只用來找到 research/ 資料夾。
"""
import os, sys
HERE = os.path.dirname(os.path.abspath(__file__))
code_dir = sys.argv[1] if len(sys.argv) > 1 else os.path.join(HERE, '../../../research/code')
algos = open(os.path.join(HERE, 'algos.js'), encoding='utf-8').read()
assert '</script' not in algos.lower(), 'algos.js 裡不能出現 </script>'
page = open(os.path.join(HERE, 'benchmark.html.tpl'), encoding='utf-8').read()
assert '/*ALGOS_JS*/' in page
page = page.replace('/*ALGOS_JS*/', algos.strip())
out = os.path.normpath(os.path.join(code_dir, '..', 'benchmark.html'))
open(out, 'w', encoding='utf-8').write(page)
print('page built:', out, len(page), 'bytes')
