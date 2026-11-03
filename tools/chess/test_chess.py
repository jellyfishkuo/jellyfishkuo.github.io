"""Jellyfish Chess 的瀏覽器測試（Playwright + Chromium）。

先在 repo 根目錄開伺服器：python3 -m http.server 8770
再跑：python3 tools/chess/test_chess.py            （全部）
      python3 tools/chess/test_chess.py rules ai     （只跑某幾組）

另外會自己開一個伺服器，把整個網站放在 /sub/repo/ 底下，測 GitHub Pages「repository 子路徑」部署。
截圖存在 tools/chess/shots/（.gitignore 已排除 png）。
"""
import functools
import http.server
import json
import os
import re
import socketserver
import sys
import threading
import time

from playwright.sync_api import sync_playwright

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), '..', '..'))
SHOTS = os.path.join(os.path.dirname(__file__), 'shots')
os.makedirs(SHOTS, exist_ok=True)
BASE = 'http://127.0.0.1:8770'
CHESS = BASE + '/games/chess/'

results = []


def check(name, cond, detail=''):
    results.append((name, bool(cond), detail))
    print(('  ✓ ' if cond else '  ✗ ') + name + (f'  — {detail}' if detail else ''))
    return cond


def launch(p):
    try:
        return p.chromium.launch()
    except Exception:  # 環境的 Playwright 版本跟瀏覽器對不上時，用系統的 Chromium
        return p.chromium.launch(executable_path=os.environ.get('CHROMIUM', '/opt/pw-browsers/chromium'))


def new_page(browser, mobile=False, **kw):
    if mobile:
        ctx = browser.new_context(viewport={'width': 375, 'height': 740}, is_mobile=True, has_touch=True, device_scale_factor=2, **kw)
    else:
        ctx = browser.new_context(viewport={'width': 1280, 'height': 900}, **kw)
    pg = ctx.new_page()
    pg.errors = []
    pg.reqs = []
    pg.on('pageerror', lambda e: pg.errors.append(str(e)))
    ctx.on('request', lambda r: pg.reqs.append(r.url))
    pg.route('**/fonts.googleapis.com/**', lambda r: r.abort())
    pg.route('**/fonts.gstatic.com/**', lambda r: r.abort())
    return pg


def open_chess(pg, route='play', base=CHESS):
    pg.goto(base + '#' + route)
    pg.wait_for_function('window.jfkChess && window.jfkChess.route === %s' % json.dumps(route))
    pg.wait_for_timeout(300)


def click_move(pg, frm, to):
    pg.click(f'#board .sq[data-sq="{frm}"]')
    pg.click(f'#board .sq[data-sq="{to}"]')


def drag_move(pg, frm, to):
    a = pg.locator(f'#board .sq[data-sq="{frm}"]').bounding_box()
    b = pg.locator(f'#board .sq[data-sq="{to}"]').bounding_box()
    pg.mouse.move(a['x'] + a['width'] / 2, a['y'] + a['height'] / 2)
    pg.mouse.down()
    pg.mouse.move(b['x'] + b['width'] / 2, b['y'] + b['height'] / 2, steps=6)
    pg.mouse.up()


def fen(pg):
    return pg.evaluate('window.jfkChess.game.fen()')


def set_play_position(pg, f):
    """對弈：從某個 FEN 開始（電腦不會先走，因為輪到使用者那方）"""
    pg.click('button:has-text("從 FEN 開始")')
    pg.fill('#dlg textarea', f)
    pg.click('#dlg button[value="ok"]')
    pg.wait_for_timeout(300)


# ───────────────────────── 測試組 ─────────────────────────

def t_home(b):
    print('[home] 首頁卡片與原有遊戲')
    pg = new_page(b)
    pg.goto(BASE + '/')
    pg.wait_for_timeout(500)
    tiles = pg.locator('#tiles > .tile')
    n = tiles.count()
    names = [tiles.nth(i).locator('h3').inner_text() for i in range(n)]
    check('首頁有「西洋棋 Chess」卡片', '西洋棋 Chess' in names, f'{n} 張卡')
    chess = pg.locator('#tiles > .tile', has_text='西洋棋 Chess')
    check('卡片有簡介', len(chess.locator('p').inner_text().strip()) > 5, chess.locator('p').inner_text())
    idx = names.index('西洋棋 Chess') if '西洋棋 Chess' in names else -1
    pg.click('#tilesMoreBtn')
    pg.wait_for_timeout(200)
    sizes = pg.evaluate("[...document.querySelectorAll('#tiles > .tile')].map(t => [Math.round(t.getBoundingClientRect().width), Math.round(t.getBoundingClientRect().height)])")
    ws = set(s[0] for s in sizes)
    row_h = {}
    for t, (w, h) in zip(names, sizes):
        row_h.setdefault(w, []).append(h)
    ch = sizes[idx]
    check('卡片寬度跟其他卡一樣', len(ws) == 1, str(ws))
    check('卡片高度沒有比其他卡大', ch[1] <= max(h for w, h in sizes), f'{ch} vs max {max(h for w, h in sizes)}')
    n_stat = int(re.search(r'\d+', pg.locator('.stat', has_text='自己做的小工具與遊戲').inner_text()).group())
    check('About 的作品數有算到西洋棋（≥ 15）', n_stat >= 15, str(n_stat))
    # 原有遊戲連結都還在、都打得開
    links = pg.evaluate("[...document.querySelectorAll('#tiles a.go')].map(a => a.getAttribute('href'))")
    bad = []
    for href in links:
        if href.startswith('http'):
            continue
        r = pg.request.get(BASE + '/' + href)
        if r.status != 200:
            bad.append((href, r.status))
    check('首頁所有遊戲連結都打得開（原有遊戲沒受影響）', not bad, str(bad) if bad else f'{len(links)} 個')
    for name, href in [('pentomino', 'games/pentomino.html'), ('zip', 'games/zip.html'), ('gomoku', 'games/vertical-gomoku.html'), ('runner', 'games/runner.html')]:
        p2 = new_page(b)
        p2.goto(BASE + '/' + href)
        p2.wait_for_timeout(700)
        check(f'原有遊戲 {name} 沒有 JS 錯誤', not p2.errors, '; '.join(p2.errors[:2]))
        p2.context.close()
    # 點卡片進入西洋棋
    pg.locator('#tiles > .tile', has_text='西洋棋 Chess').locator('h3 a').click()
    pg.wait_for_function('window.jfkChess && window.jfkChess.route')
    check('點卡片後進入 Jellyfish Chess', pg.url.rstrip('/').endswith('/games/chess') or '/games/chess/' in pg.url, pg.url)
    check('頁面有回個人網站的連結', pg.locator('.cx-top a.back').get_attribute('href').startswith('../../'))
    check('首頁沒有 JS 錯誤', not pg.errors, '; '.join(pg.errors[:2]))
    # 手機版首頁
    pm = new_page(b, mobile=True)
    pm.goto(BASE + '/')
    pm.wait_for_timeout(500)
    pm.click('#tilesMoreBtn')
    pm.wait_for_timeout(200)
    sw = pm.evaluate('document.documentElement.scrollWidth')
    check('手機首頁沒有水平溢出', sw <= 375, f'scrollWidth {sw}')
    pm.locator('#tiles > .tile', has_text='西洋棋 Chess').screenshot(path=os.path.join(SHOTS, 'home_tile_mobile.png'))
    pg.context.close(); pm.context.close()


def t_board(b):
    print('[board] 棋盤顯示')
    pg = new_page(b)
    open_chess(pg, 'play')
    check('棋盤有 64 格', pg.locator('#board .sq').count() == 64)
    check('初始有 32 個棋子', pg.locator('#board img.pc').count() == 32)
    srcs = pg.evaluate("[...document.querySelectorAll('#board img.pc')].map(i => i.complete && i.naturalWidth > 0)")
    check('棋子圖片都載入成功', all(srcs), f'{sum(srcs)}/{len(srcs)}')
    box = pg.locator('#board').bounding_box()
    check('棋盤是正方形', abs(box['width'] - box['height']) < 2, f"{box['width']:.0f}×{box['height']:.0f}")
    check('棋盤寬度夠大（桌面 ≥ 480px）', box['width'] >= 480, f"{box['width']:.0f}")
    pg.click('#btn-flip')
    pg.wait_for_timeout(100)
    first = pg.evaluate("document.querySelector('#board .sq').dataset.sq")
    check('翻轉棋盤後左上角是 h1', first == 'h1', first)
    pg.click('#btn-flip')
    check('沒有 JS 錯誤', not pg.errors, '; '.join(pg.errors[:2]))
    pg.screenshot(path=os.path.join(SHOTS, 'play_desktop.png'))
    pg.context.close()


def t_rules(b):
    print('[rules] 棋規：合法／非法、易位、吃過路兵、升變、將死、和棋')
    pg = new_page(b)
    open_chess(pg, 'play')
    # 讓電腦不要搶走（我們用 FEN 擺局面，每次只走一步）
    before = fen(pg)
    click_move(pg, 'e2', 'e5')
    check('非法走法被擋下（兵走三格）', fen(pg) == before)
    click_move(pg, 'g1', 'g3')
    check('非法走法被擋下（馬走直線）', fen(pg) == before)
    pg.click('#board .sq[data-sq="g1"]')
    dests = pg.evaluate("[...document.querySelectorAll('#board .sq.dest')].map(s => s.dataset.sq).sort()")
    check('選子後顯示合法落點（g1 馬：f3、h3）', dests == ['f3', 'h3'], str(dests))
    # 落點同時也是「上一步」的格子時，點還是要在格子正中間（以前會被上一步的底色拉到角落）
    pos = pg.evaluate("""(() => { const b = window.jfkChess.board; b.last = { from: 'f3', to: 'h3' }; b.render();
        return ['f3', 'h3'].map(s => { const el = document.querySelector(`#board .sq[data-sq="${s}"]`); const cs = getComputedStyle(el, '::after');
          return [el.classList.contains('last'), parseFloat(cs.left) / el.clientWidth, parseFloat(cs.top) / el.clientHeight, parseFloat(cs.width) / el.clientWidth]; }); })()""")
    check('落點的點在格子正中間（含上一步的格子）', all(p[0] and abs(p[1] - 0.35) < 0.01 and abs(p[2] - 0.35) < 0.01 and abs(p[3] - 0.3) < 0.01 for p in pos), str(pos))
    pg.click('#board .sq[data-sq="g1"]')
    drag_move(pg, 'g1', 'f3')
    check('拖曳走棋（Nf3）', pg.evaluate('window.jfkChess.game.history()[0]') == 'Nf3')
    pg.wait_for_function('window.jfkChess.game.history().length >= 2', timeout=30000)
    # 王車易位
    set_play_position(pg, 'r3k2r/pppqbppp/2np1n2/4p3/2B1P1b1/2NP1N2/PPPBQPPP/R3K2R w KQkq - 0 1')
    pg.click('#board .sq[data-sq="e1"]')
    dests = pg.evaluate("[...document.querySelectorAll('#board .sq.dest')].map(s => s.dataset.sq)")
    check('王車易位的落點有 g1、c1', 'g1' in dests and 'c1' in dests, str(sorted(dests)))
    pg.click('#board .sq[data-sq="g1"]')
    f = fen(pg)
    check('短易位：王到 g1、車到 f1', f.startswith('r3k2r') and pg.evaluate("window.jfkChess.game.get('g1').type") == 'k' and pg.evaluate("window.jfkChess.game.get('f1').type") == 'r')
    pg.wait_for_function('window.jfkChess.game.history().length >= 2', timeout=30000)
    # 被將軍時不能易位
    set_play_position(pg, '4k3/8/8/8/8/8/4r3/R3K2R w KQ - 0 1')
    pg.click('#board .sq[data-sq="e1"]')
    dests = pg.evaluate("[...document.querySelectorAll('#board .sq.dest')].map(s => s.dataset.sq)")
    check('被將軍時不能易位', 'g1' not in dests and 'c1' not in dests, str(sorted(dests)))
    pg.keyboard.press('Escape')
    # 吃過路兵
    set_play_position(pg, 'rnbqkbnr/ppp1p1pp/8/3pPp2/8/8/PPPP1PPP/RNBQKBNR w KQkq f6 0 3')
    click_move(pg, 'e5', 'f6')
    g = pg.evaluate("[window.jfkChess.game.history({verbose:true})[0].flags, window.jfkChess.game.get('f5'), window.jfkChess.game.get('f6')]")
    check('吃過路兵（exf6 e.p.）', 'e' in g[0] and g[1] is None and g[2]['type'] == 'p', str(g))
    pg.wait_for_function('window.jfkChess.game.history().length >= 2', timeout=30000)
    # 升變：跳出選擇，選馬
    set_play_position(pg, '8/1P6/8/8/8/2k5/8/4K3 w - - 0 1')
    click_move(pg, 'b7', 'b8')
    check('升變時跳出選擇框', pg.locator('.promo:not([hidden])').count() == 1)
    pg.click('.promo button[data-promo="n"]')
    check('升變成馬（低升變）', pg.evaluate("window.jfkChess.game.history()[0]") == 'b8=N')
    st = pg.inner_text('#play-status')
    check('王馬對單王：子力不足判和', '子力' in st and '1/2-1/2' in st, st)
    set_play_position(pg, '8/1P6/8/8/8/2k5/8/4K3 w - - 0 1')
    click_move(pg, 'b7', 'b8')
    pg.click('.promo .promo-cancel')
    check('取消升變不會走棋', pg.evaluate('window.jfkChess.game.history().length') == 0)
    # 將死
    set_play_position(pg, '6k1/5ppp/8/8/8/8/5PPP/R5K1 w - - 0 1')
    click_move(pg, 'a1', 'a8')
    pg.wait_for_timeout(400)
    st = pg.inner_text('#play-status')
    check('將死後顯示勝利', '將死' in st and '1-0' in st, st)
    # 逼和
    set_play_position(pg, '7k/8/6Q1/8/8/8/8/K7 w - - 0 1')
    click_move(pg, 'g6', 'f7')
    pg.wait_for_timeout(400)
    st = pg.inner_text('#play-status')
    check('逼和判和', '逼和' in st and '1/2-1/2' in st, st)
    # 子力不足：吃掉最後一個子
    set_play_position(pg, '8/8/8/4k3/8/3n4/4K3/8 w - - 0 1')
    click_move(pg, 'e2', 'd3')
    pg.wait_for_timeout(400)
    st = pg.inner_text('#play-status')
    check('子力不足判和', '子力' in st and '1/2-1/2' in st, st)
    # 不合法 FEN（不輪到走的一方被將軍）
    before = fen(pg)
    set_play_position(pg, '8/8/8/3k4/8/8/8/4K2Q w - - 0 1')
    check('不合法的 FEN 被拒絕', fen(pg) == before)
    check('沒有 JS 錯誤', not pg.errors, '; '.join(pg.errors[:2]))
    pg.context.close()


def t_ai(b):
    print('[ai] Stockfish 載入、電腦走棋、悔棋、重新開始、PGN 匯出')
    pg = new_page(b)
    t0 = time.time()
    open_chess(pg, 'play')
    pg.wait_for_function("window.jfkChess.engine.state === 'ready'", timeout=60000)
    check('Stockfish WASM 載入成功（Web Worker）', True, f'{time.time() - t0:.1f}s')
    wasm = [u for u in pg.reqs if '.wasm' in u]
    check('WASM 從同一個網站載入', wasm and all('/games/chess/vendor/stockfish/' in w for w in wasm), str(wasm))
    pg.click('#btn-new')
    click_move(pg, 'e2', 'e4')
    t0 = time.time()
    pg.wait_for_function('window.jfkChess.game.history().length >= 2', timeout=30000)
    check('電腦會回應一步合法的棋', pg.evaluate('window.jfkChess.game.history().length') == 2, f'{time.time() - t0:.1f}s：' + str(pg.evaluate('window.jfkChess.game.history()')))
    # 思考時不卡畫面：電腦思考時主執行緒仍然能跑 requestAnimationFrame
    pg.select_option('#movetime', '2000')
    click_move(pg, 'd2', 'd4')
    frames = pg.evaluate("""() => new Promise(r => { let n = 0; const t0 = performance.now(); const f = () => { n++; if (performance.now() - t0 < 1000) requestAnimationFrame(f); else r(n); }; requestAnimationFrame(f); })""")
    check('電腦思考時畫面不卡（1 秒內畫面更新次數）', frames >= 30, f'{frames} 次')
    pg.wait_for_function('window.jfkChess.game.history().length >= 4', timeout=30000)
    pg.select_option('#movetime', '200')
    pg.click('#btn-undo')
    h = pg.evaluate('window.jfkChess.game.history()')
    check('悔棋退回兩步（自己＋電腦）', len(h) == 2, str(h))
    pg.click('#btn-export')
    txt = pg.input_value('#dlg textarea')
    check('匯出 PGN 有標頭和棋步', '[Event "Jellyfish Chess 對弈"]' in txt and '1. e4' in txt, txt[:80].replace('\n', ' '))
    pg.click('#dlg button[value="cancel"]')
    # 執黑：電腦先走
    pg.click('.seg button[data-color="b"]')
    pg.click('#btn-new')
    pg.wait_for_function('window.jfkChess.game.history().length >= 1', timeout=30000)
    check('選黑棋時電腦（白）先走、棋盤翻轉', pg.evaluate('window.jfkChess.board.flipped') and pg.evaluate("window.jfkChess.game.turn()") == 'b')
    pg.click('.seg button[data-color="w"]')
    # 難度、思考時間設定有記住
    pg.evaluate("document.getElementById('lvl').value = 7; document.getElementById('lvl').dispatchEvent(new Event('input'))")
    p = pg.evaluate("JSON.parse(localStorage.getItem('jfk-chess-prefs-v1'))")
    check('難度設定存在 localStorage', p and p.get('level') == 7, str(p))
    pg.click('#btn-new')
    check('重新開始回到初始局面', fen(pg).startswith('rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w'))
    # 提示
    pg.click('#btn-hint')
    pg.wait_for_function("document.querySelectorAll('#board .arrows line').length > 0", timeout=20000)
    check('提示會畫出建議走法的箭頭', True)
    # 認出開局
    pg.click('#btn-new')
    click_move(pg, 'e2', 'e4')
    pg.wait_for_function('window.jfkChess.game.history().length >= 2', timeout=30000)
    if pg.evaluate("window.jfkChess.game.history()[1]") == 'c5':
        check('對弈時認出開局', '西西里' in pg.inner_text('#play-opening'), pg.inner_text('#play-opening'))
    pg.evaluate("window.jfkChess.go('analysis', {pgn: '1. e4 c5 2. Nf3 d6 3. d4 cxd4 4. Nxd4 Nf6 5. Nc3 g6'})")
    pg.wait_for_function("window.jfkChess.route === 'analysis' && document.getElementById('an-opening')")
    pg.wait_for_timeout(500)
    check('分析時認出開局與變化', '龍式' in pg.inner_text('#an-opening'), pg.inner_text('#an-opening'))
    pg.click('#an-opening a')
    pg.wait_for_function("window.jfkChess.route === 'openings'")
    check('點開局名稱跳到開局頁', 'Sicilian' in pg.inner_text('#op-head'))
    open_chess(pg, 'play')
    # 下到一半重新整理，要接回同一盤
    pg.click('#btn-new')
    click_move(pg, 'd2', 'd4')
    pg.wait_for_function('window.jfkChess.game.history().length >= 2', timeout=30000)
    pg.wait_for_timeout(300)
    before = pg.evaluate('window.jfkChess.game.history()')
    pg.reload()
    pg.wait_for_function('window.jfkChess && window.jfkChess.game.history().length >= 2', timeout=10000)
    check('重新整理後接回還沒下完的棋', pg.evaluate('window.jfkChess.game.history()') == before, str(before))
    check('沒有 JS 錯誤', not pg.errors, '; '.join(pg.errors[:2]))
    pg.context.close()


def t_pgn(b):
    print('[pgn] PGN 匯入、匯出、FEN')
    pg = new_page(b)
    open_chess(pg, 'analysis')
    pgn = '[Event "Test"]\n[White "A"]\n[Black "B"]\n[Result "1-0"]\n\n1. e4 e5 2. Bc4 Nc6 3. Qh5 Nf6 4. Qxf7# 1-0'
    pg.fill('#pgn-in', pgn)
    pg.click('#btn-load')
    pg.wait_for_timeout(300)
    n = pg.locator('#an-moves .mv').count()
    check('PGN 匯入：7 個半步', n == 7, str(n))
    pg.click('#an-moves .mv[data-ply="3"]')
    check('點任一步回到那個局面（第 3 步 Bc4 之後）', fen(pg).startswith('rnbqkbnr/pppp1ppp/8/4p3/2B1P3/8/PPPP1PPP/RNBQK1NR b'), fen(pg))
    pg.keyboard.press('ArrowRight')
    check('鍵盤右鍵到下一步', pg.evaluate("+document.querySelector('#an-moves .mv.cur').dataset.ply") == 4)
    pg.fill('#pgn-in', '1. e4 e5 2. Ke3')
    pg.click('#btn-load')
    pg.wait_for_timeout(300)
    check('不合法的 PGN 會提示錯誤', pg.locator('#toast').is_visible() and '讀不懂' in pg.inner_text('#toast'))
    pg.fill('#pgn-in', 'r1bqkb1r/pppp1Qpp/2n2n2/4p3/2B1P3/8/PPPP1PPP/RNB1K1NR b KQkq - 0 4')
    pg.click('#btn-load')
    pg.wait_for_timeout(300)
    check('FEN 載入（將死局面）', pg.evaluate('window.jfkChess.game.isCheckmate()'))
    # 對弈的 PGN 匯入 → 匯出往返
    open_chess(pg, 'play')
    pg.click('button:has-text("匯入 PGN")')
    pg.fill('#dlg textarea', '1. d4 d5 2. c4 e6 3. Nc3 Nf6')
    pg.click('#dlg button[value="ok"]')
    pg.wait_for_timeout(300)
    h = pg.evaluate('window.jfkChess.game.history()')
    check('對弈：匯入 PGN 接著下', h[:6] == ['d4', 'd5', 'c4', 'e6', 'Nc3', 'Nf6'], str(h))
    pg.click('#btn-export')
    txt = pg.input_value('#dlg textarea')
    check('匯出的 PGN 再匯入得到同樣的棋步', '1. d4 d5 2. c4 e6 3. Nc3 Nf6' in txt, txt.split('\n\n')[-1][:60])
    with pg.expect_download() as dl:
        pg.click('#dlg button[value="ok"]')
    check('下載 .pgn 檔', dl.value.suggested_filename.endswith('.pgn'), dl.value.suggested_filename)
    check('沒有 JS 錯誤', not pg.errors, '; '.join(pg.errors[:2]))
    pg.context.close()


def t_analysis(b):
    print('[analysis] Stockfish 整盤分析')
    pg = new_page(b)
    open_chess(pg, 'analysis')
    pg.click('button:has-text("範例：Morphy")')
    pg.wait_for_timeout(500)
    check('載入棋局後自動開始分析（不用按按鈕）', '分析中' in pg.inner_text('#an-progress') or '完成' in pg.inner_text('#an-progress'), pg.inner_text('#an-progress'))
    pg.select_option('#an-depth', '12')
    t0 = time.time()
    pg.wait_for_function("document.getElementById('an-progress').textContent.includes('完成')", timeout=180000)
    check('整盤分析完成', True, f'{time.time() - t0:.1f}s')
    tags = pg.evaluate("[...document.querySelectorAll('#an-moves .mv')].map(b => (b.querySelector('.tag')||{}).className || '')")
    best = sum(1 for t in tags if 'best' in t)
    check('棋步標出最佳走法與錯誤等級', best >= 10 and len(tags) == 33, f'★ {best} 步，有標記 {sum(1 for t in tags if t)}/{len(tags)}')
    check('評估曲線有畫出來', pg.locator('#an-chart path, svg.chart path').count() >= 1)
    pg.click('#an-moves .mv[data-ply="33"]')
    info = pg.inner_text('#an-info')
    check('顯示實際走法與最佳走法', '實際走法' in info and '最佳走法' in info, info[:60].replace('\n', ' '))
    check('最後一步 Rd8# 是最佳走法', '最佳走法' in info and 'Rd8#' in info)
    pg.click('#an-moves .mv[data-ply="8"]')
    info = pg.inner_text('#an-info')
    check('顯示引擎建議的變化（PV）', '變化' in info)
    check('總結有平均損失與錯誤數', '平均每步損失' in pg.inner_text('#an-sum'))
    # 圖表點擊跳到那一步
    pg.locator('svg.chart').scroll_into_view_if_needed()
    pg.wait_for_timeout(200)
    box = pg.locator('svg.chart').bounding_box()
    pg.mouse.click(box['x'] + box['width'] * 0.5, box['y'] + box['height'] / 2)
    ply = pg.evaluate("+document.querySelector('#an-moves .mv.cur').dataset.ply")
    check('點評估曲線跳到對應的步', 14 <= ply <= 20, str(ply))
    # 一個明顯的大錯一定要抓到
    pg.fill('#pgn-in', '1. e4 e5 2. Nf3 Nc6 3. Bc4 Nd4 4. Nxe5 Qg5 5. Nxf7 Qxg2 6. Rf1 Qxe4+ 7. Be2 Nf3#')
    pg.click('#btn-load')
    pg.wait_for_function("document.getElementById('an-progress').textContent.includes('完成')", timeout=180000)
    tags = pg.evaluate("[...document.querySelectorAll('#an-moves .mv')].map(b => [b.innerText.split('\\n')[0].trim(), (b.querySelector('.tag')||{}).className || ''])")
    bl = [t[0] for t in tags if 'blunder' in t[1]]
    check('抓到白方的 Blunder（Nxe5 或 Nxf7）', any(m.startswith('Nx') for m in bl), str(bl))
    # 即時分析（MultiPV）
    pg.click('#an-moves .mv[data-ply="2"]')
    pg.wait_for_function("document.querySelectorAll('#an-lines .ln').length >= 2", timeout=30000)
    check('即時分析顯示多條變化', pg.locator('#an-lines .ln').count() >= 2)
    pg.screenshot(path=os.path.join(SHOTS, 'analysis_desktop.png'), full_page=True)
    check('沒有 JS 錯誤', not pg.errors, '; '.join(pg.errors[:2]))
    pg.context.close()


def solve_current(pg, wrong_first=False):
    """照題庫的答案解目前這一題；回傳 (成功, 解析文字)"""
    pg.wait_for_function("document.getElementById('pz-status').textContent.includes('輪到你')", timeout=10000)
    p = pg.evaluate("(() => { const n = document.getElementById('pz-title').textContent.replace('題目 #', ''); return window.__puzzles.find(x => x.id === 'jc' + n || x.id === 'li' + n); })()")
    moves = p['moves'].split(' ')
    if wrong_first:
        legal = pg.evaluate("window.jfkChess.game.moves({verbose:true}).map(m => m.from + m.to + (m.promotion||''))")
        bad = next(u for u in legal if u != moves[1] and not u[4:])
        before = fen(pg)
        click_move(pg, bad[:2], bad[2:4])
        pg.wait_for_timeout(900)
        check('戰術：走錯會退回原局面', fen(pg) == before)
        check('戰術：走錯會顯示提示', '提示' in pg.inner_text('#pz-status'), pg.inner_text('#pz-status')[:50])
    for i in range(1, len(moves), 2):
        u = moves[i]
        click_move(pg, u[:2], u[2:4])
        if len(u) == 5:
            pg.click(f'.promo button[data-promo="{u[4]}"]')
        if i + 1 < len(moves):
            pg.wait_for_function("document.getElementById('pz-status').textContent.includes('繼續')", timeout=5000)
    pg.wait_for_selector('#pz-explain:not([hidden])', timeout=5000)
    return p, pg.inner_text('#pz-explain')


def t_tactics(b):
    print('[tactics] 戰術題答案驗證、提示、收藏、錯題、正確率')
    pg = new_page(b)
    open_chess(pg, 'tactics')
    pg.evaluate("import('./js/tactics.js').then(m => { window.__puzzles = m.PUZZLES; })")
    pg.wait_for_function('window.__puzzles')
    total = pg.evaluate('window.__puzzles.length')
    # 每一題的答案在瀏覽器裡用 chess.js 再驗一次：每一步合法、走完不會是對手將死自己
    res = pg.evaluate("""import('./vendor/chessjs/chess.js').then(({Chess}) => window.__puzzles.map(p => {
        const g = new Chess(p.fen); const ms = p.moves.split(' ');
        try { for (const u of ms) g.move({from:u.slice(0,2), to:u.slice(2,4), promotion:u[4]}); } catch (e) { return p.id + ' illegal'; }
        if (ms.length % 2) return p.id + ' odd';
        if (p.themes.includes('mate') && !g.isCheckmate()) return p.id + ' not mate';
        return null; }).filter(Boolean))""")
    check(f'{total} 題的答案都合法、殺王題最後真的將死', not res, str(res[:5]))
    themes = pg.evaluate("Object.fromEntries(['fork','pin','skewer','discovered','deflection','defender','mate','defense'].map(t => [t, window.__puzzles.filter(p => p.themes.includes(t)).length]))")
    check('8 種題型都有題目', all(v > 0 for v in themes.values()), str(themes))
    # 解一題（先走錯一次）
    p, ex = solve_current(pg, wrong_first=True)
    check('多步驟解答可以解完並顯示解析', '解析' in ex and p['last'] in ex, f"{p['id']} {len(p['moves'].split())} 半步")
    check('走錯過的題目記為答錯', '答錯' in pg.inner_text('#pz-status') or '錯題' in pg.inner_text('#pz-status'))
    wrong_n = pg.evaluate("+document.querySelector('[data-filter=wrong] .n').textContent")
    check('錯題本多了一題', wrong_n >= 1, str(wrong_n))
    # 收藏
    pg.click('#pz-fav')
    pg.wait_for_timeout(200)
    check('收藏題目', pg.inner_text('#pz-fav').startswith('★'))
    # 下一題：直接解對
    pg.click('#pz-next')
    p2, ex2 = solve_current(pg)
    check('直接解對顯示「答對了」', '答對' in pg.inner_text('#pz-status'), pg.inner_text('#pz-status'))
    acc = pg.inner_text('#pz-acc')
    check('正確率 50%（一錯一對）', acc == '50%', acc)
    # 錯題重練
    pg.click('[data-filter="wrong"]')
    pg.wait_for_timeout(900)
    check('錯題重練出現剛剛做錯的題', pg.inner_text('#pz-title').replace('題目 #', '') == p['id'][2:], pg.inner_text('#pz-title'))
    solve_current(pg)
    pg.wait_for_timeout(300)
    check('重練答對後離開錯題本', pg.evaluate("+document.querySelector('[data-filter=wrong] .n').textContent") == 0)
    # 殺王題：任何將死都算對（最後一步）
    pg.click('[data-filter="mate"]')
    pg.wait_for_timeout(900)
    p3, _ = solve_current(pg)
    check('殺王題可以解', 'mate' in p3['themes'])
    # 從戰術題點「用引擎分析這題」：帶整條解答過去，自動開始分析
    pg.click('#pz-explain button:has-text("用引擎分析這題")')
    pg.wait_for_function("window.jfkChess.route === 'analysis'")
    pg.wait_for_function("document.getElementById('an-progress').textContent.includes('完成')", timeout=180000)
    n = pg.locator('#an-moves .mv[data-ply]').count()
    check('戰術題 → 分析：整條解答自動分析完', n == len(p3['moves'].split()), f'{n} 步')
    check('戰術題 → 分析：停在輪到你的那一步', pg.evaluate("+document.querySelector('#an-moves .mv.cur').dataset.ply") == 1)
    check('戰術題 → 分析：棋盤方向跟解題方一樣', pg.evaluate('window.jfkChess.board.flipped') == (p3['side'] == 'b'))
    # 只有一個局面（沒有棋步）也會自動算評估
    pg.fill('#pgn-in', '6k1/5ppp/8/8/8/8/5PPP/R5K1 w - - 0 1')
    pg.click('#btn-load')
    pg.wait_for_function("document.getElementById('an-progress').textContent.includes('完成')", timeout=60000)
    check('單一局面也自動算出評估', '#' in pg.inner_text('#an-chart-tip') or '+' in pg.inner_text('#an-chart-tip'), pg.inner_text('#an-chart-tip'))
    open_chess(pg, 'tactics')      # 回到戰術頁會直接出下一題
    # 看答案
    pg.wait_for_function("document.getElementById('pz-status').textContent.includes('輪到你')", timeout=10000)
    pg.click('#pz-reveal')
    pg.wait_for_selector('#pz-explain:not([hidden])', timeout=15000)
    check('「看答案」會播完解答並顯示解析', '解析' in pg.inner_text('#pz-explain'))
    # 收藏篩選
    pg.click('[data-filter="fav"]')
    pg.wait_for_timeout(900)
    check('收藏篩選出現收藏的題目', pg.inner_text('#pz-title').replace('題目 #', '') == p['id'][2:])
    check('沒有 JS 錯誤', not pg.errors, '; '.join(pg.errors[:2]))
    pg.screenshot(path=os.path.join(SHOTS, 'tactics_desktop.png'))
    pg.context.close()


def t_openings(b):
    print('[openings] 開局研究、[endgames] 殘局練習')
    pg = new_page(b)
    open_chess(pg, 'openings')
    n = pg.locator('#op-list button').count()
    check('8 個開局', n == 8, str(n))
    for op in ['italian', 'ruy', 'sicilian', 'french', 'carokann', 'qgd', 'london', 'kid']:
        pg.click(f'#op-list [data-op="{op}"]')
        txt = pg.inner_text('#op-head') + pg.inner_text('#wide')
        ok = all(k in txt for k in ['ECO', '開局目的', '主要變化', '典型戰術', '常見錯誤'])
        if not check(f'開局 {op} 有 ECO、目的、變化、戰術、錯誤', ok):
            break
    pg.click('#op-list [data-op="italian"]')
    wb = pg.locator('#wide').bounding_box(); bb = pg.locator('#board').bounding_box()
    check('開局說明放在棋盤下方的寬區塊', wb['y'] > bb['y'] + bb['height'] and wb['width'] >= bb['width'] - 20, f"說明 y={wb['y']:.0f} 寬 {wb['width']:.0f}，棋盤底 {bb['y'] + bb['height']:.0f}")
    pg.locator('#wide .line-btn').nth(1).click()
    pg.wait_for_timeout(300)
    check('點下方的變化會換到棋盤上', pg.evaluate('window.jfkChess.game.history().length') == 0 and 'Giuoco' in pg.inner_text('#op-line'), pg.inner_text('#op-line'))
    pg.click('#op-head button:has-text("從頭看主線")')
    pg.click('#op-next'); pg.click('#op-next'); pg.click('#op-next')
    check('一步一步看主線（附說明）', 'Nf3' in pg.inner_text('#op-note') or '攻擊 e5' in pg.inner_text('#op-note'), pg.inner_text('#op-note'))
    pg.click('#op-drill')
    click_move(pg, 'e2', 'e4')
    pg.wait_for_timeout(700)
    check('練習模式：電腦接著走主線', pg.evaluate('window.jfkChess.game.history()') == ['e4', 'e5'])
    click_move(pg, 'b1', 'c3')
    check('練習模式：走錯不接受並提示', pg.evaluate('window.jfkChess.game.history().length') == 2 and '不是主線' in pg.inner_text('#op-note'))
    pg.click('#op-fav')
    pg.wait_for_timeout(200)
    check('收藏開局', '★' in pg.inner_text('#op-fav'))
    # 殘局
    open_chess(pg, 'endgames')
    n = pg.locator('#eg-list .item').count()
    names = pg.inner_text('#eg-list')
    check('殘局：K+Q、K+R、王兵、對位、Lucena、Philidor 都有', all(k in names for k in ['K+Q', 'K+R', '王兵', '對位', 'Lucena', 'Philidor']), f'{n} 題')
    pg.click('#eg-list [data-eg="kqk-2"]')
    check('殘局局面正確載入', fen(pg).startswith('8/8/8/8/8/8/1k6/6KQ w'))
    click_move(pg, 'h1', 'c6')
    pg.wait_for_function('window.jfkChess.game.history().length >= 2', timeout=20000)
    check('殘局：電腦（Stockfish）防守回應', pg.evaluate('window.jfkChess.game.history().length') == 2)
    pg.click('#eg-list [data-eg="opp-1"]')
    check('守和題：使用者執黑、棋盤翻轉', pg.evaluate('window.jfkChess.board.flipped'))
    click_move(pg, 'e6', 'f6')       # 錯的一步（只有 Kd6 守得住）
    pg.wait_for_function("document.getElementById('eg-status').textContent.includes('守不住') || window.jfkChess.game.history().length >= 2", timeout=20000)
    pg.wait_for_timeout(300)
    check('守和題：走錯會被判定守不住', '守不住' in pg.inner_text('#eg-status'), pg.inner_text('#eg-status')[:60])
    pg.click('#eg-reset')
    click_move(pg, 'e6', 'd6')
    pg.wait_for_function('window.jfkChess.game.history().length >= 2', timeout=20000)
    check('守和題：正確的 Kd6 不會被判輸', '守不住' not in pg.inner_text('#eg-status'))
    check('沒有 JS 錯誤', not pg.errors, '; '.join(pg.errors[:2]))
    pg.context.close()


def t_storage(b):
    print('[storage] IndexedDB 儲存、備份與還原')
    pg = new_page(b, accept_downloads=True)
    open_chess(pg, 'play')
    pg.click('#btn-new')
    set_play_position(pg, '6k1/5ppp/8/8/8/8/5PPP/R5K1 w - - 0 1')
    click_move(pg, 'a1', 'a8')
    pg.wait_for_timeout(500)
    open_chess(pg, 'my')
    pg.wait_for_selector('#my-overview')
    pg.wait_for_timeout(300)
    check('對局存進 IndexedDB 並顯示勝場', pg.inner_text('#my-overview').startswith('1 勝 0 和 0 負'), pg.inner_text('#my-overview')[:20])
    pg.click('#my-add-note')
    pg.fill('#dlg input[name="title"]', '測試筆記 <b>不是粗體</b>')
    pg.fill('#dlg textarea[name="body"]', '后要跟對方王保持馬步距離')
    pg.click('#dlg button[value="ok"]')
    pg.wait_for_timeout(300)
    check('新增筆記（使用者輸入不會被當成 HTML）', '測試筆記 <b>不是粗體</b>' in pg.inner_text('#my-notes'))
    with pg.expect_download() as dl:
        pg.click('#my-backup')
    path = dl.value.path()
    data = json.load(open(path, encoding='utf-8'))
    check('下載完整 JSON 備份', data['app'] == 'jellyfish-chess' and len(data['stores']['games']) >= 1 and len(data['stores']['notes']) == 1,
          ', '.join(f'{k} {len(v)}' for k, v in data['stores'].items()))
    # 清除再還原
    pg.on('dialog', lambda d: d.accept())
    pg.click('button:has-text("清除全部資料")')
    pg.click('#dlg button[value="ok"]')
    pg.wait_for_timeout(400)
    check('清除後沒有資料', pg.inner_text('#my-overview').startswith('0 勝 0 和 0 負'))
    pg.set_input_files('#my-restore-file', path)
    pg.wait_for_selector('#dlg[open]')
    pg.click('#dlg button[value="ok"]')
    pg.wait_for_timeout(600)
    check('從備份還原對局', pg.inner_text('#my-overview').startswith('1 勝 0 和 0 負'))
    check('從備份還原筆記', '后要跟對方王保持馬步距離' in pg.inner_text('#my-notes'))
    # 壞掉的備份檔不會動到資料
    bad = os.path.join(SHOTS, 'bad-backup.json')
    json.dump({'app': 'other'}, open(bad, 'w'))
    pg.set_input_files('#my-restore-file', bad)
    pg.wait_for_timeout(300)
    check('拒絕不是 Jellyfish Chess 的備份檔', '不能還原' in pg.inner_text('#toast'))
    os.remove(bad)
    # 重新整理後資料還在（真的寫進 IndexedDB）
    pg.reload()
    pg.wait_for_selector('#my-overview')
    pg.wait_for_timeout(300)
    check('重新整理後資料還在', pg.inner_text('#my-overview').startswith('1 勝 0 和 0 負'))
    check('沒有 JS 錯誤', not pg.errors, '; '.join(pg.errors[:2]))
    pg.context.close()


def t_mobile(b):
    print('[mobile] 手機版操作與版面')
    pm = new_page(b, mobile=True)
    for r in ['play', 'tactics', 'analysis', 'openings', 'endgames', 'my']:
        open_chess(pm, r)
        pm.wait_for_timeout(500)
        sw = pm.evaluate('document.documentElement.scrollWidth')
        check(f'手機 375px：{r} 沒有水平溢出', sw <= 375, f'scrollWidth {sw}')
        pm.screenshot(path=os.path.join(SHOTS, f'mobile_{r}.png'))
    open_chess(pm, 'play')
    pm.click('#btn-new')
    box = pm.locator('#board').bounding_box()
    check('手機棋盤佔滿寬度', box['width'] >= 330, f"{box['width']:.0f}px")
    pm.tap('#board .sq[data-sq="e2"]')
    pm.tap('#board .sq[data-sq="e4"]')
    pm.wait_for_function('window.jfkChess.game.history().length >= 2', timeout=30000)
    check('手機點兩下走棋，電腦回應', True)
    # 320px、放大字體
    p3 = b.new_context(viewport={'width': 320, 'height': 640}, is_mobile=True, has_touch=True).new_page()
    p3.route('**/fonts.googleapis.com/**', lambda r: r.abort())
    for r in ['play', 'tactics', 'analysis', 'openings', 'endgames', 'my']:
        open_chess(p3, r)
        p3.add_style_tag(content='html { font-size: 125% !important; }')
        p3.wait_for_timeout(300)
        sw = p3.evaluate('document.documentElement.scrollWidth')
        check(f'手機 320px＋放大字體：{r} 沒有水平溢出', sw <= 320, f'scrollWidth {sw}')
    # 平板
    pt = b.new_context(viewport={'width': 820, 'height': 1180}, is_mobile=True, has_touch=True).new_page()
    pt.route('**/fonts.googleapis.com/**', lambda r: r.abort())
    open_chess(pt, 'analysis')
    sw = pt.evaluate('document.documentElement.scrollWidth')
    check('平板 820px 沒有水平溢出', sw <= 820, f'scrollWidth {sw}')
    pt.screenshot(path=os.path.join(SHOTS, 'tablet_analysis.png'))
    # 淺色主題
    pl = new_page(b, color_scheme='light')
    open_chess(pl, 'tactics')
    check('淺色主題可以正常顯示', pl.evaluate("document.documentElement.dataset.theme") == 'light')
    pl.screenshot(path=os.path.join(SHOTS, 'light_tactics.png'))
    check('沒有 JS 錯誤', not pm.errors and not pl.errors, '; '.join((pm.errors + pl.errors)[:2]))
    pm.context.close(); p3.context.close(); pt.context.close(); pl.context.close()


class _Sub(http.server.SimpleHTTPRequestHandler):
    """把 repo 放在 /sub/repo/ 底下，模擬 username.github.io/<repo>/ 這種專案頁面路徑"""
    def translate_path(self, path):
        path = path.split('?', 1)[0].split('#', 1)[0]
        if not path.startswith('/sub/repo/'):
            return '/nonexistent'
        return os.path.join(ROOT, path[len('/sub/repo/'):])

    def log_message(self, *a):
        pass


def t_subpath(b):
    print('[subpath] GitHub Pages repository 子路徑')
    srv = socketserver.TCPServer(('127.0.0.1', 0), _Sub)
    port = srv.server_address[1]
    threading.Thread(target=srv.serve_forever, daemon=True).start()
    base = f'http://127.0.0.1:{port}/sub/repo/games/chess/'
    pg = new_page(b)
    bad = []
    pg.on('response', lambda r: r.status >= 400 and bad.append((r.status, r.url)))
    open_chess(pg, 'play', base=base)
    pg.wait_for_function("window.jfkChess.engine.state === 'ready'", timeout=60000)
    click_move(pg, 'e2', 'e4')
    pg.wait_for_function('window.jfkChess.game.history().length >= 2', timeout=30000)
    check('子路徑下 Stockfish 能載入並走棋', True)
    for r in ['tactics', 'openings', 'endgames', 'analysis', 'my']:
        open_chess(pg, r, base=base)
    pg.wait_for_timeout(500)
    check('子路徑下所有資源都找得到（沒有 404）', not bad, str(bad[:3]))
    check('沒有 JS 錯誤', not pg.errors, '; '.join(pg.errors[:2]))
    pg.context.close()
    srv.shutdown()


def t_offline(b):
    print('[offline] 離線：已載入的功能還能用')
    ctx = b.new_context(viewport={'width': 1280, 'height': 900})
    pg = ctx.new_page()
    pg.route('**/fonts.googleapis.com/**', lambda r: r.abort())
    errs = []
    pg.on('pageerror', lambda e: errs.append(str(e)))
    open_chess(pg, 'play')
    pg.wait_for_function("window.jfkChess.engine.state === 'ready'", timeout=60000)
    pg.evaluate('navigator.serviceWorker.ready.then(() => true)')
    pg.reload()
    pg.wait_for_function("navigator.serviceWorker.controller !== null", timeout=10000)
    for r in ['tactics', 'analysis', 'openings', 'endgames', 'my']:
        open_chess(pg, r)
    pg.wait_for_timeout(800)
    ctx.set_offline(True)
    pg.reload()
    open_chess(pg, 'play')
    pg.wait_for_function("window.jfkChess.engine.state === 'ready'", timeout=60000)
    click_move(pg, 'e2', 'e4')
    pg.wait_for_function('window.jfkChess.game.history().length >= 2', timeout=30000)
    check('離線重新整理後還能跟 Stockfish 下棋', True)
    open_chess(pg, 'tactics')
    check('離線時戰術題可用', pg.locator('#pz-title').inner_text().startswith('題目'))
    check('沒有 JS 錯誤', not errs, '; '.join(errs[:2]))
    ctx.close()



def t_new(b):
    print('[new] 棋鐘、對完復盤、戰術積分、分析支線、照實戰練開局')
    pg = new_page(b)
    open_chess(pg, 'play')
    pg.wait_for_function("window.jfkChess.engine.state === 'ready'", timeout=60000)
    # 棋鐘
    pg.select_option('#time-control', '3+2')
    pg.click('#btn-new')
    check('有時間控制時顯示雙方的棋鐘', pg.locator('.player .clock').all_inner_texts() == ['3:00', '3:00'], str(pg.locator('.player .clock').all_inner_texts()))
    for a, c in [('e2', 'e4'), ('d2', 'd4'), ('g1', 'f3')]:
        n = pg.evaluate('window.jfkChess.game.history().length')
        click_move(pg, a, c)
        pg.wait_for_function(f'window.jfkChess.game.history().length >= {n + 2}', timeout=30000)
    w = pg.evaluate('window.jfkChess._play.clock.w')
    check('走棋會扣時間、每步加秒', 175000 < w < 190000, f'{w / 1000:.1f} 秒')
    pg.click('#btn-undo')
    check('悔棋時棋鐘也退回去', abs(pg.evaluate('window.jfkChess._play.clock.w') - w) > 100)
    pg.evaluate('window.jfkChess._play.clock.w = 1500')
    pg.wait_for_function("document.getElementById('play-status').textContent.includes('時間到')", timeout=10000)
    check('時間用完判負', '你輸了' in pg.inner_text('#play-status'), pg.inner_text('#play-status'))
    pg.click('#btn-export')
    check('PGN 記下時間控制', '[TimeControl "180+2"]' in pg.input_value('#dlg textarea'))
    pg.click('#dlg button[value="cancel"]')
    # 對完自動復盤
    pg.wait_for_function("document.getElementById('btn-review-open')", timeout=180000)
    rv = pg.inner_text('#play-review')
    check('對完自動復盤：統計你的失誤、指出轉捩點或沒有失誤', '最佳' in rv and ('轉捩點' in rv or '沒有明顯的失誤' in rv), rv[:80].replace('\n', ' '))
    pg.click('#btn-review-open')
    pg.wait_for_function("window.jfkChess.route === 'analysis'")
    pg.wait_for_timeout(600)
    check('從復盤打開分析：直接讀存好的分數，不用重算', '已載入存好的分析' in pg.inner_text('#an-progress'), pg.inner_text('#an-progress'))
    # 分析支線
    pg.fill('#pgn-in', '1. e4 e5 2. Nf3 Nc6 3. Bb5 a6 4. Ba4 Nf6')
    pg.click('#btn-load')
    pg.click('#an-moves .mv[data-ply="4"]')
    click_move(pg, 'f1', 'c4')
    pg.wait_for_timeout(300)
    check('試走不同的棋：開一條支線，原本的棋譜保留', pg.locator('#an-moves .mv[data-ply]').count() == 8 and pg.locator('#an-moves .var').count() == 1, pg.inner_text('#an-moves .var'))
    click_move(pg, 'g8', 'f6')
    check('在支線上繼續走', 'Nf6' in pg.inner_text('#an-moves .var'))
    pg.keyboard.press('ArrowLeft'); pg.keyboard.press('ArrowLeft')
    pg.wait_for_timeout(200)
    check('支線退到底回到主線', pg.evaluate("+document.querySelector('#an-moves .mv.cur').dataset.ply") == 4)
    pg.locator('#an-moves .var .vdel').click()
    check('刪除支線', pg.locator('#an-moves .var').count() == 0)
    # 戰術積分
    open_chess(pg, 'tactics')
    pg.evaluate("import('./js/tactics.js').then(m => { window.__puzzles = m.PUZZLES; })")
    pg.wait_for_function('window.__puzzles')
    r0 = int(pg.inner_text('#pz-rating'))
    p1, _ = solve_current(pg)
    r1 = int(pg.inner_text('#pz-rating'))
    check('答對第一次做的題，戰術積分上升', r1 > r0, f'{r0} → {r1}')
    check('狀態列顯示積分變化', '積分' in pg.inner_text('#pz-status'), pg.inner_text('#pz-status'))
    pg.click('#pz-next')
    pg.wait_for_function("document.getElementById('pz-status').textContent.includes('輪到你')", timeout=10000)
    pg.click('#pz-reveal')
    pg.wait_for_selector('#pz-explain:not([hidden])', timeout=15000)
    r2 = int(pg.inner_text('#pz-rating'))
    check('看答案（答錯）戰術積分下降', r2 < r1, f'{r1} → {r2}')
    # 照實戰練開局
    pg.evaluate("""import('./js/store.js').then(({db}) => db.put('games', {id: 'gtest', date: new Date().toISOString(), pgn: '1. e4 e5 2. Nf3 Nc6 3. Bc4 Bc5 4. d3 Nf6 *', mode: 'play', level: 4, myColor: 'w', result: '*', outcome: 'loss', moves: 8}))""")
    open_chess(pg, 'openings')
    pg.wait_for_selector('#op-mine-list .item', timeout=5000)
    check('開局頁找出你離開書上走法的地方', 'd3' in pg.inner_text('#op-mine-list') and 'c3' in pg.inner_text('#op-mine-list'), pg.inner_text('#op-mine-list')[:80])
    pg.locator('#op-mine-list .item').first.locator('button:has-text("練習這條")').click()
    pg.wait_for_timeout(300)
    check('從實戰開始練習那條開局', '練習' in pg.inner_text('#op-note'))
    # 我的開局樹（上面已經存了一盤 1.e4 e5 2.Nf3 Nc6 3.Bc4 Bc5 4.d3 的對局）
    open_chess(pg, 'openings')
    pg.wait_for_selector('#tree-list', timeout=5000)
    check('開局樹列出你第一步走過的著法', 'e4' in pg.inner_text('#tree-list'), pg.inner_text('#tree-list').replace('\n', ' ')[:60])
    pg.click('#tree-list [data-move="e4"]')
    pg.wait_for_timeout(200)
    check('點著法往下一層，棋盤跟著走', pg.evaluate('window.jfkChess.game.history()') == ['e4'] and 'e5' in pg.inner_text('#tree-list'))
    check('開局樹顯示盤數與勝率', '盤' in pg.inner_text('#tree-list'))
    # 教練模式
    open_chess(pg, 'play')
    pg.select_option('#time-control', '')
    pg.click('#btn-new')
    if pg.get_attribute('#btn-coach', 'aria-pressed') != 'true':
        pg.click('#btn-coach')
    check('教練模式顯示評估條', pg.is_visible('#evalbar'))
    click_move(pg, 'e2', 'e4')
    pg.wait_for_function('window.jfkChess.game.history().length >= 2', timeout=30000)
    pg.wait_for_timeout(1500)
    q = pg.evaluate("(() => { const g = window.jfkChess.game; for (const m of g.moves({verbose: true}).filter(m => m.piece === 'q')) { g.move(m); const hit = g.moves({verbose: true}).some(x => x.to === m.to); g.undo(); if (hit) return m.from + m.to; } return null; })()")
    if q:
        n = pg.evaluate('window.jfkChess.game.history().length')
        click_move(pg, q[:2], q[2:4])
        pg.wait_for_selector('#coach-retry', timeout=30000)
        check('教練模式：送后的大錯會被攔下來', 'Blunder' in pg.inner_text('#play-coach') or 'Mistake' in pg.inner_text('#play-coach'), pg.inner_text('#play-coach')[:50])
        check('教練模式：攔下來時電腦還沒走', pg.evaluate('window.jfkChess.game.history().length') == n + 1)
        pg.click('#coach-retry')
        check('教練模式：重走這步會退回去', pg.evaluate('window.jfkChess.game.history().length') == n)
    pg.click('#btn-coach')
    open_chess(pg, 'my')
    pg.wait_for_selector('#my-rating')
    check('「我的」顯示戰術積分', pg.inner_text('#my-rating') == str(r2), pg.inner_text('#my-rating'))
    check('沒有 JS 錯誤', not pg.errors, '; '.join(pg.errors[:2]))
    pg.context.close()

GROUPS = {'home': t_home, 'board': t_board, 'rules': t_rules, 'ai': t_ai, 'pgn': t_pgn, 'analysis': t_analysis,
          'tactics': t_tactics, 'openings': t_openings, 'storage': t_storage, 'mobile': t_mobile, 'subpath': t_subpath, 'offline': t_offline, 'new': t_new}

if __name__ == '__main__':
    want = sys.argv[1:] or list(GROUPS)
    with sync_playwright() as p:
        browser = launch(p)
        for g in want:
            try:
                GROUPS[g](browser)
            except Exception as e:  # 一組掛掉不影響其他組
                check(f'[{g}] 執行完畢', False, repr(e)[:300])
        browser.close()
    bad = [r for r in results if not r[1]]
    print(f'\n共 {len(results)} 項，失敗 {len(bad)} 項')
    for r in bad:
        print('  ✗', r[0], r[2])
    sys.exit(1 if bad else 0)
