"""產生 research/overview.html（Research 總覽：演算法關係圖、閱讀路線、比較表）

用法（跟其他 Demo 一樣）：
    cd tools/research/overview && python3 -B build.py ../../../research/code
參數可省略，省略時直接寫到 repo 的 research/overview.html。

資料來源：這裡自己維護一份清單（NODES、ROUTES），沒有從 index.html 讀。
原因是有幾頁（skyline、efim、gsp-spade、bloom-filter、gspan、benchmark）可能還沒放上首頁，
而且這頁需要的欄位（改良自誰、掃描次數、額外結構……）首頁卡片本來就沒有。
新增 Demo 時：在 NODES 加一個節點（給座標、group、from），必要時放進 ROUTES，再重新執行這支程式。

連結的頁面不存在時（research/<page>.html 還沒做好），節點會畫成虛線框、顯示「即將推出」、不放連結；
等那頁做好之後重新 build 一次就會自動變成可以點的連結。
"""
import html, json, os, sys

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.abspath(os.path.join(HERE, '../../..'))
RESEARCH = os.path.join(REPO, 'research')

def exists(page):
    return os.path.exists(os.path.join(RESEARCH, page + '.html'))

esc = html.escape

# ── 分組（圖上的一條一條橫帶） ───────────────────────────────
# id, 名稱, 顏色, 帶子的 (x, y, 寬, 高)
GROUPS = [
    ('inc',     '增量資料庫',  '#22c55e', (4, 6, 572, 82)),
    ('freq',    '頻繁樣式',    '#8b5cf6', (4, 98, 572, 142)),
    ('rule',    '規則與序列',  '#c084fc', (4, 250, 572, 142)),
    ('graph',   '圖形',        '#f472b6', (586, 250, 310, 142)),
    ('hui',     '高效益樣式',  '#f59e0b', (4, 402, 892, 126)),
    ('stream',  '資料串流',    '#06b6d4', (4, 538, 892, 92)),
    ('spatial', '空間資料',    '#60a5fa', (4, 640, 892, 92)),
]
GMAP = {g[0]: g for g in GROUPS}
# 清單和比較表用的順序（圖上的排法是為了箭頭好畫，跟這個不同）
LIST_ORDER = [GMAP[g] for g in ('freq', 'rule', 'graph', 'hui', 'inc', 'stream', 'spatial')]
SVG_W, SVG_H = 900, 738

# 欄的中心 x
A, B, C, D, E = 78, 262, 472, 648, 818
NODE_W, NODE_H = 136, 42

# ── 節點：每個演算法一個 ─────────────────────────────────────
# from：(來源 id, 'solid' 改良自／延伸自, 'dash' 借用同一個想法, 說明)
# 比較表的欄位：idea 核心想法、scans 掃描資料庫次數、cand 會不會產生候選、struct 額外結構、fit 適合的情況
# 掃描次數裡「範例資料」的數字，是各 Demo 頁用預設資料、預設門檻跑到最後顯示的值（2026/10 核對過）。
NODES = [
    # 頻繁樣式
    dict(id='apriori', name='Apriori', year='1994', page='apriori', group='freq', x=A, y=170,
         idea='不頻繁的組合，包含它的更大組合也一定不頻繁；從 1 個商品開始一層一層往上長',
         scans='每一層 1 次（範例資料 4 次）', cand='會：合併＋剪枝產生候選，再掃資料庫數',
         struct='只有候選清單', fit='資料不大、樣式不長；最好懂，也是所有方法比較的基準',
         short='一層一層合併、剪枝、計數，後面幾乎每個方法都從它出發。'),
    dict(id='fp', name='FP-Growth', year='2000', page='fp-growth', group='freq', x=B, y=138,
         idea='把交易壓成一棵 FP-tree，沿條件模式基底建條件樹、遞迴挖',
         scans='2 次（數次數＋建樹）', cand='不會：只在樹上長出真的出現過的組合',
         struct='FP-tree、條件樹', fit='交易的共同前綴多、樹放得進記憶體',
         short='把交易壓成一棵樹，只掃兩次、不產生候選。',
         frm=[('apriori', 'solid', '不再一層一層猜候選，改成在樹上長')]),
    dict(id='eclat', name='Eclat', year='1997', page='eclat', group='freq', x=B, y=202,
         idea='轉成垂直格式，每個商品記 TID 集合，兩兩取交集就是支持度',
         scans='1 次（建垂直表）', cand='會：同一等價類兩兩配對，但交集直接得到次數，不回頭掃',
         struct='TID 集合（垂直表）', fit='稀疏資料；很密的資料改用 dEclat 的 diffset',
         short='把資料轉成「每個商品出現在哪幾筆」，用交集算支持度。',
         frm=[('apriori', 'solid', '一樣靠向下封閉性，但改用垂直格式、深度優先')]),
    dict(id='charm', name='CHARM', sub='封閉樣式', year='2002', page='closed-patterns', group='freq', x=C, y=202,
         idea='比較兩個樣式的 tidset 是相等、包含還是互不包含，用四條性質合併、吸收，直接找出封閉樣式',
         scans='1 次（建 tidset）', cand='會，但四條性質會提早合併或刪掉，最後再做子集合檢查',
         struct='tidset、已找到的封閉樣式（做子集合檢查）', fit='頻繁樣式多到看不完、又要保留所有次數（無損壓縮）',
         short='頻繁樣式太多時，只留封閉樣式，次數一個都不少。',
         frm=[('eclat', 'solid', '建在 Eclat 的垂直格式上')]),
    # 規則與序列
    dict(id='rules', name='關聯規則', year='1994', page='association-rules', group='rule', x=B, y=290,
         idea='把頻繁樣式切成 X → Y，算信賴度和提升度；同一個樣式後件越大，信賴度只會越低',
         scans='0 次（直接用頻繁樣式和次數）', cand='會：後件逐層合併＋剪枝',
         struct='頻繁樣式和它們的次數', fit='想得到「買了 X 的人也會買 Y」這種可以拿來用的結論',
         short='從頻繁樣式切出規則，看信賴度和提升度。',
         frm=[('apriori', 'solid', 'Apriori 論文的第二步：從頻繁樣式產生規則')]),
    dict(id='gsp', name='GSP', sub='序列', year='1996', page='gsp-spade', group='rule', x=B, y=354,
         idea='序列版的 Apriori：候選序列一層一層猜，再掃資料庫數有幾位顧客包含它',
         scans='每一層 1 次', cand='會',
         struct='候選序列', fit='序列短、想先看懂序列探勘在數什麼',
         short='序列版的 Apriori，一層一層產生候選序列。',
         frm=[('apriori', 'solid', '把 Apriori 搬到有先後順序的序列上')]),
    dict(id='prefixspan', name='PrefixSpan', year='2001', page='prefixspan', group='rule', x=C, y=290,
         idea='用頻繁的前綴把資料庫投影成越來越小的後綴，只接真的出現過的商品',
         scans='原始資料 1 次，之後掃越來越小的投影資料庫', cand='不會（樣式成長）',
         struct='投影資料庫（偽投影只記位置）', fit='序列長、資料量大',
         short='用前綴投影資料庫，分「同一次」和「下一次」兩種延伸。',
         frm=[('fp', 'solid', '跟 FP-Growth 一樣是分而治之的樣式成長')]),
    dict(id='spade', name='SPADE', sub='序列', year='2001', page='gsp-spade', group='rule', x=C, y=354,
         idea='序列版的 Eclat：每個樣式記它出現在哪些 (顧客, 第幾次)，用時間先後的連接算次數',
         scans='1 次（建垂直 id-list）', cand='會：同前綴兩兩連接，但連接完就知道次數',
         struct='垂直 id-list (sid, eid)', fit='序列資料放得進記憶體，想少掃資料庫',
         short='序列版的 Eclat，用 (sid, eid) 清單連接。',
         frm=[('eclat', 'solid', '把 Eclat 的垂直格式搬到序列上')]),
    # 圖形
    dict(id='gspan', name='gSpan', sub='圖形樣式', year='2002', page='gspan', group='graph', x=D + 40, y=322,
         idea='用 DFS code 給每個子圖一個最小的寫法，只從最右路徑長一條邊，不重複也不漏',
         scans='每次延伸只看目前樣式的嵌入（出現位置）', cand='不會（樣式成長）',
         struct='DFS code、每張圖裡的嵌入清單', fit='化學分子、程式呼叫圖這類「東西之間有連線」的資料',
         short='從集合、序列再到圖：找很多張圖裡共同出現的子圖。',
         frm=[('prefixspan', 'dash', '一樣是深度優先的樣式成長：集合 → 序列 → 圖')]),
    # 高效益
    dict(id='twophase', name='Two-Phase', year='2005', page='two-phase', group='hui', x=B, y=465,
         idea='效益沒有向下封閉性，改用有向下封閉性的上界 TWU 照 Apriori 剪，最後再算一次真的效益',
         scans='第一階段每一層 1 次＋第二階段 1 次（範例資料 4 次）', cand='會（範例 15 個候選，8 個白算）',
         struct='候選清單', fit='第一次學「用上界剪枝」；TWU 至今仍是幾乎每個方法的第一步',
         short='用 TWU 當上界照 Apriori 挑候選，再掃一次算真效益。',
         frm=[('apriori', 'solid', '第一階段完全照 Apriori 的方式，只是用 TWU 剪')]),
    dict(id='upgrowth', name='UP-Growth', year='2010', page='up-growth', group='hui', x=C, y=465,
         idea='把交易壓成 UP-Tree，節點只記到自己為止的效益，用 DGU、DGN、DLU、DLN 收緊上界',
         scans='3 次（算 TWU、建樹、驗證候選）', cand='會，但比 Two-Phase 少（範例 12 個，Two-Phase 15 個）',
         struct='UP-Tree、條件樹', fit='資料一直增加、想用樹一筆一筆插入的情況',
         short='用樹當結構、上界比 TWU 緊，候選少很多。',
         frm=[('twophase', 'solid', '一樣兩階段，但上界比 TWU 緊'), ('fp', 'solid', 'UP-Tree 的建法跟 FP-tree 一樣')]),
    dict(id='huiminer', name='HUI-Miner', year='2012', page='high-utility', group='hui', x=D, y=465,
         idea='每個組合一張 utility list（iutil、rutil），合併就得到真正的效益，用 Σiutil＋Σrutil 剪',
         scans='2 次（算 TWU、建 utility list）', cand='不會（one-phase）',
         struct='utility list', fit='一般情況的高效益基準方法，好懂又好改',
         short='utility list 合併直接算出效益，不需要候選。',
         frm=[('upgrowth', 'solid', '不再兩階段：不用候選、不用回頭驗證')]),
    dict(id='efim', name='EFIM', year='2015', page='efim', group='hui', x=E, y=436,
         idea='投影資料庫並合併相同的交易，用子樹效益、局部效益兩個更緊的上界，靠 utility-bin 陣列一次算完',
         scans='原始資料 2 次，之後掃越來越小的投影資料庫', cand='不會',
         struct='投影資料庫、utility-bin 陣列', fit='資料大、要又快又省記憶體',
         short='投影＋合併交易，上界更緊、記憶體更省。',
         frm=[('huiminer', 'solid', '不再為每個組合建 list，改用投影資料庫和更緊的上界')]),
    dict(id='topk', name='Top-k', sub='TKO', year='2016', page='top-k-hui', group='hui', x=E, y=496,
         idea='不給門檻，直接要前 k 名：最小堆積裝目前的前 k 名，門檻邊挖邊往上調',
         scans='2 次（跟 HUI-Miner 一樣）', cand='不會',
         struct='utility list、最小堆積', fit='不知道門檻該設多少',
         short='不用猜門檻，排行榜裝滿後門檻自動往上升。',
         frm=[('huiminer', 'solid', '一樣用 utility list，加上會往上調的門檻')]),
    # 增量
    dict(id='fup', name='FUP', year='1996', page='incremental', group='inc', x=B, y=48,
         idea='舊樣式只數新進來的交易；新冒出的候選先用引理篩，只有少數要回頭掃舊資料',
         scans='每一層掃新資料 1 次，有新候選通過引理時才回頭掃舊資料（範例：新資料 3 次、舊資料 1 次）',
         cand='會（照 Apriori 產生，再用引理篩）',
         struct='上次的結果：頻繁樣式和次數', fit='一批一批新增、新資料跟舊資料長得差不多',
         short='新交易進來時只更新受影響的部分，結果跟重算一樣。',
         frm=[('apriori', 'solid', '把 Apriori 改成只處理新增的那幾筆')]),
    dict(id='cantree', name='CanTree', year='2007', page='cantree', group='inc', x=C, y=48,
         idea='商品照事先定好的固定順序插進樹，新交易直接沿一條路徑加次數，不用重排重建',
         scans='每筆交易只讀 1 次（不用先數次數）', cand='不會（挖的時候跟 FP-Growth 一樣）',
         struct='CanTree（存所有商品）', fit='資料一直新增、門檻常常改',
         short='固定順序的 FP-tree，新交易來了直接插。',
         frm=[('fp', 'solid', 'FP-tree 改成固定順序，挖法照搬')]),
    # 串流
    dict(id='sw', name='滑動視窗', year='', page='sliding-window', group='stream', x=A, y=592,
         idea='只看最近 W 筆：進來那筆的子集合 +1、離開那筆的 −1，其他組合不用動',
         scans='單趟：每筆進來、離開各處理一次', cand='不會',
         struct='計數表（視窗裡出現過的組合）', fit='只在乎最近的資料、商品種類少',
         short='只看最近 W 筆，一進一出即時更新頻繁樣式。'),
    dict(id='lossy', name='Lossy Counting', name2='Space-Saving', year='2002·2005', page='stream-counting', group='stream', x=B, y=592,
         idea='Lossy Counting 分桶清掉次數太少的（只少算、最多 εN）；Space-Saving 只用 k 格計數器（只多算、最多 N/k）',
         scans='單趟', cand='不會',
         struct='帶誤差的計數表／k 格計數器', fit='記憶體不夠記每個商品，要找熱門商品、即時排行',
         short='記憶體不夠時近似計數，誤差有上限。'),
    dict(id='cms', name='Count-Min', sub='Sketch', year='2005', page='count-min', group='stream', x=C, y=592,
         idea='d 列 × w 欄的格子，每列用雜湊算出一格 +1，查詢取 d 格的最小值，只會多算',
         scans='單趟', cand='不會',
         struct='d × w 計數表、d 個雜湊函數', fit='任何商品都要能查、分店的表要能相加',
         short='不記名稱、只記格子，任何商品都查得到。',
         frm=[('bloom', 'dash', '一樣把東西用好幾個雜湊撒進格子，只是格子改成計數')]),
    dict(id='bloom', name='Bloom Filter', year='1970', page='bloom-filter', group='stream', x=D, y=592,
         idea='m 格位元、k 個雜湊；登錄時把 k 格設成 1，查詢時 k 格都是 1 才說「可能在」，有 0 就一定不在',
         scans='單趟', cand='不會',
         struct='m 格位元陣列、k 個雜湊函數', fit='快速判斷「看過沒有」，可以接受偶爾誤判成「可能在」',
         short='用很少的位元判斷「有沒有看過」，只會誤判成可能在。'),
    # 空間
    dict(id='quad', name='四元樹', year='1974', page='spatial', group='spatial', x=A, y=694,
         idea='依空間從中線切成四塊，點多的地方切細，範圍查詢時整塊跳過不相干的格子',
         scans='—（不是交易資料；建樹時每個點插入一次）', cand='—',
         struct='四元樹', fit='點分布不平均、要做範圍查詢',
         short='把地圖依密度切格子，範圍查詢整塊跳過。'),
    dict(id='coloc', name='共位樣式', year='2004', page='spatial', group='spatial', x=B, y=694,
         idea='用「距離 ≤ r」取代交易，算參與指數 PI，照 Apriori 一層一層剪',
         scans='—（每一層找一次列實例）', cand='會（跟 Apriori 一樣合併＋剪枝）',
         struct='鄰近關係、列實例', fit='想知道哪幾種店總是開在彼此附近',
         short='頻繁樣式搬到地圖上：哪幾種店總是開在一起。'),
    dict(id='rtree', name='R-tree', year='1984', page='rtree', group='spatial', x=C, y=694,
         idea='用剛好包住一群點的框（MBR）建平衡樹；kNN 用優先佇列依距離一路打開最近的框',
         scans='—（建樹時每個點插入一次）', cand='—',
         struct='R-tree、優先佇列', fit='資料庫裡的地圖資料、找最近的 k 個',
         short='依資料包框的平衡樹，最近 k 家店一下就找到。'),
    dict(id='dbscan', name='DBSCAN', year='1996', page='dbscan', group='spatial', x=D, y=694,
         idea='圈裡鄰居夠多的是核心點，沿著核心點把鄰居一圈一圈拉進來長成一群',
         scans='—（每個點做 1 次 ε 範圍查詢）', cand='—',
         struct='佇列（可再加四元樹、R-tree 加速找鄰居）', fit='不知道要分幾群、群的形狀奇怪、有雜訊',
         short='依密度分群，不用先說幾群，還會標出雜訊。'),
    dict(id='skyline', name='Skyline', sub='BNL・SFS', year='2001·2003', page='skyline', group='spatial', x=E, y=694,
         idea='找出沒有被任何一家「每一項都不輸、至少一項更好」打敗的點；BNL 用視窗兩兩比較，SFS 先排序讓視窗只進不出',
         scans='視窗放得下就 1 輪；放不下要再讀暫存檔', cand='—',
         struct='視窗（目前還沒被打敗的點）、暫存檔', fit='多個條件一起挑（又便宜又近），不想自己訂權重',
         short='又便宜又近：找出不被任何一家全面打敗的店。'),
]
NMAP = {n['id']: n for n in NODES}
for n in NODES:
    n.setdefault('frm', [])
    n['live'] = exists(n['page'])

BENCH_LIVE = exists('benchmark')

# ── 閱讀路線 ────────────────────────────────────────────────
ROUTES = [
    dict(title='入門路線', sub='頻繁樣式的三種基本做法，再往外延伸', color='#8b5cf6', stops=[
        ('apriori', '先懂支持度、向下封閉性，這是每一頁的共同語言。'),
        ('fp', '同一份資料改用樹：只掃兩次、不產生候選。'),
        ('eclat', '第三種做法：垂直格式和交集。'),
        ('charm', '答案太多怎麼辦？只留封閉樣式。'),
        ('rules', '把頻繁樣式變成「買 X 也買 Y」的規則。'),
        ('prefixspan', '加上時間順序，變成序列樣式。'),
    ]),
    dict(title='高效益路線', sub='不只看買幾次，還看賺多少', color='#f59e0b', stops=[
        ('apriori', '先確定向下封閉性懂了，才看得出效益為什麼不能直接剪。'),
        ('twophase', '用 TWU 當上界，照 Apriori 挑候選、再驗證。'),
        ('upgrowth', '換成樹，上界收得更緊、候選更少。'),
        ('huiminer', 'utility list：不要候選，合併就算出效益。'),
        ('efim', '投影資料庫加更緊的上界，現在常用的快方法。'),
        ('topk', '不知道門檻設多少時，直接要前 k 名。'),
    ]),
    dict(title='串流與空間路線', sub='資料停不下來，或資料有位置', color='#06b6d4', stops=[
        ('sw', '只看最近 W 筆，一進一出怎麼更新。'),
        ('lossy', '記憶體不夠時近似計數，誤差有上限。'),
        ('cms', '只記格子不記名稱的計數草稿。'),
        ('quad', '換到地圖：四元樹切格子、共位樣式找一起出現的店。'),
        ('rtree', '依資料包框的索引，找最近的 k 家店。'),
        ('dbscan', '用密度把地圖上的點分群。'),
    ]),
]
ROUTE_EXTRA = {  # 路線走完可以接著看的
    '串流與空間路線': ['bloom', 'skyline'],
    '入門路線': ['gsp', 'spade', 'gspan'],
    '高效益路線': ['fup', 'cantree'],
}

# ── 產生 HTML 片段 ──────────────────────────────────────────
def href(n):
    return n['page'] + '.html'

def node_label(n):
    return n['name'] + (('・' + n['name2']) if n.get('name2') else '') + ((' ' + n['sub']) if n.get('sub') else '')

def link_or_soon(n, cls=''):
    lab = esc(node_label(n))
    if n['live']:
        return f'<a class="{cls}" href="{href(n)}">{lab}</a>'
    return f'<span class="{cls} soon">{lab}</span>'

def soon_tag(n):
    return '' if n['live'] else '<span class="soon-tag">即將推出</span>'

def svg_graph():
    out = []
    out.append(f'<svg class="graph" viewBox="0 0 {SVG_W} {SVG_H}" width="{SVG_W}" height="{SVG_H}" role="img" '
               f'aria-label="演算法關係圖：箭頭代表改良自或延伸自">')
    out.append('<defs>'
               '<marker id="ar" viewBox="0 0 10 10" refX="9" refY="5" markerWidth="7" markerHeight="7" orient="auto-start-reverse">'
               '<path d="M0,1 L10,5 L0,9 z" fill="#a78bfa"/></marker>'
               '<marker id="ar2" viewBox="0 0 10 10" refX="9" refY="5" markerWidth="7" markerHeight="7" orient="auto-start-reverse">'
               '<path d="M0,1 L10,5 L0,9 z" fill="#22d3ee"/></marker>'
               '<marker id="arh" viewBox="0 0 10 10" refX="9" refY="5" markerWidth="7" markerHeight="7" orient="auto-start-reverse">'
               '<path d="M0,1 L10,5 L0,9 z" fill="#fbbf24"/></marker>'
               '</defs>')
    for gid, gname, col, (x, y, w, h) in GROUPS:
        out.append(f'<g class="band"><rect x="{x}" y="{y}" width="{w}" height="{h}" rx="12" fill="{col}" fill-opacity="0.07" '
                   f'stroke="{col}" stroke-opacity="0.35"/>'
                   f'<text x="{x + 12}" y="{y + 19}" fill="{col}" class="band-t">{esc(gname)}</text></g>')
    # 圖例（放在頻繁樣式右邊的空位）
    lx, ly = 600, 112
    any_soon = any(not n['live'] for n in NODES)
    out.append(f'<g class="legend"><rect x="{lx - 10}" y="{ly - 14}" width="306" height="{124 if any_soon else 94}" rx="12" fill="#0b0b14" stroke="#262640"/>'
               f'<path class="e" d="M{lx},{ly + 8} L{lx + 40},{ly + 8}" marker-end="url(#ar)"/>'
               f'<text x="{lx + 52}" y="{ly + 12}" class="lg">改良自／延伸自</text>'
               f'<path class="e dash" d="M{lx},{ly + 34} L{lx + 40},{ly + 34}" marker-end="url(#ar2)"/>'
               f'<text x="{lx + 52}" y="{ly + 38}" class="lg">借用同一個想法</text>'
               f'<rect x="{lx}" y="{ly + 50}" width="40" height="20" rx="5" fill="#151527" stroke="#8b5cf6"/>'
               f'<text x="{lx + 52}" y="{ly + 64}" class="lg">點方框進入那個 Demo</text>'
               + (f'<rect x="{lx}" y="{ly + 80}" width="40" height="20" rx="5" fill="none" stroke="#8a8aa3" stroke-dasharray="4 3"/>'
                  f'<text x="{lx + 52}" y="{ly + 94}" class="lg">虛線框：即將推出</text>' if any_soon else '')
               + '</g>')
    # 箭頭：同一個來源有好幾條時，起點稍微錯開
    edges = []
    for n in NODES:
        for src, kind, why in n['frm']:
            edges.append((NMAP[src], n, kind, why))
    out.append('<g class="edges">')
    hw = NODE_W / 2
    for s, t, kind, why in edges:
        if t['x'] < s['x']:       # 往左
            x1, x2 = s['x'] - hw, t['x'] + hw
        else:
            x1, x2 = s['x'] + hw, t['x'] - hw
        y1, y2 = s['y'], t['y']
        sibs = [e for e in edges if e[0] is s and (e[1]['x'] < s['x']) == (t['x'] < s['x'])]
        if len(sibs) > 1:
            sibs.sort(key=lambda e: e[1]['y'])
            i = sibs.index((s, t, kind, why))
            y1 = s['y'] + (i - (len(sibs) - 1) / 2) * min(6, 26 / (len(sibs) - 1))
        if abs(y1 - y2) < 0.5:
            d = f'M{x1:.0f},{y1:.1f} L{x2 - (2 if x2 > x1 else -2):.0f},{y2:.1f}'
        else:
            dx = (x2 - x1) * 0.55
            d = f'M{x1:.0f},{y1:.1f} C{x1 + dx:.0f},{y1:.1f} {x2 - dx:.0f},{y2:.1f} {x2 - (2 if x2 > x1 else -2):.0f},{y2:.1f}'
        cls = 'e dash' if kind == 'dash' else 'e'
        mk = 'ar2' if kind == 'dash' else 'ar'
        out.append(f'<path class="{cls}" data-s="{s["id"]}" data-t="{t["id"]}" d="{d}" marker-end="url(#{mk})">'
                   f'<title>{esc(node_label(s))} → {esc(node_label(t))}：{esc(why)}</title></path>')
    out.append('</g>')
    for n in NODES:
        col = GMAP[n['group']][2]
        x, y = n['x'] - hw, n['y'] - NODE_H / 2
        two = bool(n.get('name2'))
        title = n['name'] + ('／' + n['name2'] if two else '')
        if two:
            lines = [(n['name'], 0), (n['name2'], 1)]
        else:
            lines = [(n['name'] + ((' ' + n['sub']) if n.get('sub') else ''), 0)]
        meta = n['year'] if n['live'] else '即將推出'
        txt = []
        if two:
            txt.append(f'<text x="{n["x"]}" y="{n["y"] - 7}" class="nt nt2">{esc(n["name"])}</text>')
            txt.append(f'<text x="{n["x"]}" y="{n["y"] + 6}" class="nt nt2">{esc(n["name2"])}</text>')
        else:
            txt.append(f'<text x="{n["x"]}" y="{n["y"] + 1}" class="nt">{esc(lines[0][0])}</text>')
        if meta:
            txt.append(f'<text x="{n["x"]}" y="{n["y"] + (17 if two else 16)}" class="ny">{esc(meta)}</text>')
        body = (f'<rect x="{x:.0f}" y="{y:.0f}" width="{NODE_W}" height="{NODE_H}" rx="9" '
                f'fill="#151527" stroke="{col}"/>' + ''.join(txt))
        tip = f'<title>{esc(title)}：{esc(n["short"])}{"" if n["live"] else "（即將推出）"}</title>'
        if n['live']:
            out.append(f'<a class="node" href="{href(n)}" data-id="{n["id"]}" aria-label="{esc(title)}">{tip}{body}</a>')
        else:
            out.append(f'<g class="node soon" data-id="{n["id"]}">{tip}{body}</g>')
    out.append('</svg>')
    return '\n'.join(out)

def group_list():
    """手機（和電腦）都看得到的直向清單：每一組列出節點、一句話、改良自誰"""
    out = []
    for gid, gname, col, _ in LIST_ORDER:
        items = [n for n in NODES if n['group'] == gid]
        out.append(f'<section class="grp" style="--gc:{col}"><h3>{esc(gname)}</h3><ul>')
        for n in items:
            frm = ''
            if n['frm']:
                parts = []
                for src, kind, why in n['frm']:
                    s = NMAP[src]
                    word = '改良自' if kind == 'solid' else '借用'
                    parts.append(f'<span class="from {"dash" if kind == "dash" else ""}">{word} {esc(node_label(s))}</span>')
                frm = '<div class="froms">' + ''.join(parts) + '</div>'
            year = f'<span class="yr">{esc(n["year"])}</span>' if n['year'] else ''
            out.append(f'<li>{link_or_soon(n, "nm")}{year}{soon_tag(n)}<p>{esc(n["short"])}</p>{frm}</li>')
        out.append('</ul></section>')
    return '\n'.join(out)

def routes():
    out = []
    for r in ROUTES:
        out.append(f'<div class="card route" style="--rc:{r["color"]}"><h2>{esc(r["title"])}</h2>'
                   f'<p class="route-sub">{esc(r["sub"])}</p><ol>')
        for nid, why in r['stops']:
            n = NMAP[nid]
            out.append(f'<li>{link_or_soon(n, "nm")}{soon_tag(n)}<p>{esc(why)}</p></li>')
        out.append('</ol>')
        extra = ROUTE_EXTRA.get(r['title'])
        if extra:
            ex = '、'.join(link_or_soon(NMAP[e], 'ex') for e in extra)
            out.append(f'<p class="route-next">走完可以接著看：{ex}</p>')
        out.append('</div>')
    return '\n'.join(out)

def table():
    out = ['<table class="cmp"><thead><tr><th>演算法</th><th>類別</th><th>核心想法</th><th>掃描資料庫</th>'
           '<th>產生候選？</th><th>需要的額外結構</th><th>適合的情況</th></tr></thead><tbody>']
    for gid, gname, col, _ in LIST_ORDER:
        for n in [n for n in NODES if n['group'] == gid]:
            cand = n['cand']
            ccls = 'yes' if cand.startswith('會') else 'no' if cand.startswith('不會') else 'na'
            out.append(f'<tr><th scope="row">{link_or_soon(n, "nm")}{soon_tag(n)}</th>'
                       f'<td><span class="gtag" style="--gc:{col}">{esc(gname)}</span></td>'
                       f'<td>{esc(n["idea"])}</td><td class="mono">{esc(n["scans"])}</td>'
                       f'<td class="c-{ccls}">{esc(cand)}</td><td>{esc(n["struct"])}</td><td>{esc(n["fit"])}</td></tr>')
    out.append('</tbody></table>')
    return '\n'.join(out)

def bench():
    if BENCH_LIVE:
        return '<a class="btn-link" href="benchmark.html">進入效能比賽場 →</a>'
    return '<span class="btn-link soon">效能比賽場（即將推出）</span>'

def main():
    pages = sorted({n['page'] for n in NODES})
    live = sum(exists(p) for p in pages)
    tpl = open(os.path.join(HERE, 'overview.html.tpl'), encoding='utf-8').read()
    rep = {
        '<!--GRAPH-->': svg_graph(),
        '<!--LIST-->': group_list(),
        '<!--ROUTES-->': routes(),
        '<!--TABLE-->': table(),
        '<!--BENCH-->': bench(),
        '<!--N_ALGO-->': str(len(NODES)),
        '/*EDGES_JSON*/null': json.dumps([[s, n['id']] for n in NODES for s, _, _ in n['frm']]),
    }
    for k, v in rep.items():
        assert k in tpl, k
        tpl = tpl.replace(k, v)
    dst = os.path.join(sys.argv[1], '..', 'overview.html') if len(sys.argv) > 1 else os.path.join(RESEARCH, 'overview.html')
    open(dst, 'w', encoding='utf-8').write(tpl)
    soon = [p for p in pages if not exists(p)] + ([] if BENCH_LIVE else ['benchmark'])
    print('page built:', os.path.normpath(dst))
    print(f'{len(NODES)} 個演算法、{len(pages)} 個頁面，已存在 {live} 頁；即將推出：{", ".join(soon) or "無"}')

if __name__ == '__main__':
    main()
