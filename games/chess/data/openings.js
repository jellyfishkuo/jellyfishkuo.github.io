// 開局資料（手寫）。每一條棋譜都由 tools/chess/check_data.mjs 用 chess.js 檢查合法，
// 戰術與錯誤的結論再用 Stockfish 看最後局面的評估確認。
// main：主線；notes：主線第 n 個半步（從 1 算）走完後的說明；lines：其他變化；
// tactics / mistakes：{ title, line（從初始局面開始的完整棋譜）, text, eval（check_data 確認的結果方向：'w' 白好、'b' 黑好、'=' 均勢） }
export const OPENINGS = [
  {
    id: 'italian', name: '義大利開局', en: 'Italian Game', eco: 'C50–C59', side: 'w',
    main: '1. e4 e5 2. Nf3 Nc6 3. Bc4 Bc5 4. c3 Nf6 5. d3 d6 6. O-O O-O 7. Re1 a6 8. Bb3 Ba7',
    notes: {
      3: 'Nf3 一出來就攻擊 e5 兵，同時準備易位。',
      5: 'Bc4 瞄準 f7——黑方王旁邊只有王自己保護的弱點。',
      6: '黑方也把象放到對稱的 c5，瞄準 f2。',
      7: 'c3 準備 d4 搶中心（把 c5 的象趕走）。',
      9: 'd3 是現代下法：不急著打開中心，先完成發展、慢慢調動（又叫 Giuoco Pianissimo，「非常安靜的棋」）。',
      13: 'Re1 支撐 e4，之後常走 Nbd2–f1–g3 把馬繞到王翼。',
      15: 'a6／Bb3／Ba7：雙方都把象退到安全的位置，避免被 b4、d4 或 ...Na5 趕來趕去。',
    },
    purpose: [
      '最快的發展：馬、象各出一個，第 4 步就能易位。',
      '象在 c4 盯著 f7，配合馬 g5 或后 f3／h5 有直接的攻擊機會。',
      '中心計畫：c3 + d4 建立兩個中心兵；或 d3 慢慢佈陣、之後在王翼發動攻擊。',
    ],
    lines: [
      { name: 'Giuoco Piano 主線（5.d4）', eco: 'C54', moves: '1. e4 e5 2. Nf3 Nc6 3. Bc4 Bc5 4. c3 Nf6 5. d4 exd4 6. cxd4 Bb4+ 7. Bd2 Bxd2+ 8. Nbxd2 d5', text: '白方立刻 d4 建立中心，黑方用 ...Bb4+ 換掉一隻象，再 ...d5 打擊中心。' },
      { name: '雙馬防禦（Two Knights）', eco: 'C57–C59', moves: '1. e4 e5 2. Nf3 Nc6 3. Bc4 Nf6 4. Ng5 d5 5. exd5 Na5 6. Bb5+ c6 7. dxc6 bxc6 8. Be2 h6 9. Nf3 e4 10. Ne5', text: '黑方用 ...Nf6 反擊 e4。白方 4.Ng5 雙打 f7，黑方正確的做法是 ...d5 再 ...Na5，用一個兵換來快速發展。' },
      { name: '伊凡斯棄兵（Evans Gambit）', eco: 'C51–C52', moves: '1. e4 e5 2. Nf3 Nc6 3. Bc4 Bc5 4. b4 Bxb4 5. c3 Ba5 6. d4 exd4 7. O-O', text: '白方送一個 b 兵，換來 c3、d4 的節奏，快速佔領中心、打開線路攻擊。' },
    ],
    tactics: [
      { title: '炸肝攻擊（Fried Liver）：Nxf7!', line: '1. e4 e5 2. Nf3 Nc6 3. Bc4 Nf6 4. Ng5 d5 5. exd5 Nxd5 6. Nxf7 Kxf7 7. Qf3+ Ke6 8. Nc3', eval: 'w', text: '黑方 5...Nxd5 不夠小心，白馬直接吃 f7 棄子，把黑王拉到中央；Qf3+ 同時攻擊 d5 的馬，再 Nc3 加壓。黑王無處躲，白方攻勢很強。' },
      { title: '叉子詭計（Fork Trick）：...Nxe4!', line: '1. e4 e5 2. Nf3 Nc6 3. Bc4 Nf6 4. Nc3 Nxe4 5. Nxe4 d5 6. Bd3 dxe4 7. Bxe4', eval: '=', text: '白方 4.Nc3 之後，黑方可以先用馬吃 e4（暫時送一個子），再 ...d5 叉住象和馬，把子拿回來，順便換掉白方的中心兵。' },
    ],
    mistakes: [
      { title: '雙馬防禦裡 5...Nxd5?', line: '1. e4 e5 2. Nf3 Nc6 3. Bc4 Nf6 4. Ng5 d5 5. exd5 Nxd5', eval: 'w', text: '看起來很自然的吃回兵，卻讓白方可以 6.Nxf7（炸肝攻擊）或 6.d4。正確的是 5...Na5，趕走 c4 的象。' },
      { title: '貪吃 e5 兵的陷阱（Blackburne Shilling）', line: '1. e4 e5 2. Nf3 Nc6 3. Bc4 Nd4 4. Nxe5 Qg5 5. Nxf7 Qxg2 6. Rf1 Qxe4+ 7. Be2 Nf3#', eval: 'b', text: '黑方 3...Nd4 是個陷阱（本身不是好棋，4.Nxd4 或 4.O-O 就好）。白方貪吃 4.Nxe5? 之後，黑后吃 g2、再將軍，最後 Nf3# 悶殺。教訓：對手送子時，先檢查它的威脅。' },
    ],
  },
  {
    id: 'ruy', name: '西班牙開局（魯伊・洛佩斯）', en: 'Ruy Lopez', eco: 'C60–C99', side: 'w',
    main: '1. e4 e5 2. Nf3 Nc6 3. Bb5 a6 4. Ba4 Nf6 5. O-O Be7 6. Re1 b5 7. Bb3 d6 8. c3 O-O 9. h3',
    notes: {
      5: 'Bb5 攻擊的是「保護 e5 的馬」，給 e5 間接施壓。',
      6: '...a6（Morphy 防禦）先問象要不要換。',
      7: '退到 a4 保持壓力；現在 Bxc6 + Nxe5 還不成立（黑方有 ...Qd4）。',
      9: '先易位，不急著保護 e4（黑方吃 e4 白方有 Re1 拿回）。',
      13: '...b5 趕走 a4 的象，象退到 b3 繼續瞄準 f7。',
      15: 'c3 準備 d4，同時給象留一條 c2 的退路。',
      17: 'h3 防止 ...Bg4 牽制 f3 的馬，為 d4 做準備。這是封閉式西班牙的經典局面。',
    },
    purpose: [
      '白方用 Bb5 對 e5 做「慢慢加壓」，不求馬上得利，而是長期的中心優勢。',
      '典型計畫：c3 + d4 建立中心；Nbd2–f1–g3 把馬調到王翼。',
      '黑方的計畫：...b5、...Na5 在后翼取得空間，或在中心以 ...exd4、...c5 反擊。',
    ],
    lines: [
      { name: '柏林防禦（Berlin）', eco: 'C65–C67', moves: '1. e4 e5 2. Nf3 Nc6 3. Bb5 Nf6 4. O-O Nxe4 5. d4 Nd6 6. Bxc6 dxc6 7. dxe5 Nf5 8. Qxd8+ Kxd8', text: '「柏林牆」：很早換掉后，黑方失去易位權，但有雙象、結構穩固，是頂尖棋手的和棋利器。' },
      { name: '交換變例（Exchange）', eco: 'C68–C69', moves: '1. e4 e5 2. Nf3 Nc6 3. Bb5 a6 4. Bxc6 dxc6 5. O-O f6 6. d4', text: '白方直接用象換馬，讓黑方變成疊兵。白方的目標是進入殘局：王翼 4 兵對 3 兵，能做出通路兵。' },
      { name: '馬歇爾攻擊（Marshall Attack）', eco: 'C89', moves: '1. e4 e5 2. Nf3 Nc6 3. Bb5 a6 4. Ba4 Nf6 5. O-O Be7 6. Re1 b5 7. Bb3 O-O 8. c3 d5 9. exd5 Nxd5 10. Nxe5 Nxe5 11. Rxe5 c6', text: '黑方送一個兵，換來快速出子和對白王的攻擊（...Bd6、...Qh4）。' },
    ],
    tactics: [
      { title: '諾亞方舟陷阱（Noah\'s Ark）：困住 b3 的象', line: '1. e4 e5 2. Nf3 Nc6 3. Bb5 a6 4. Ba4 d6 5. d4 b5 6. Bb3 Nxd4 7. Nxd4 exd4 8. Qxd4 c5 9. Qd5 Be6 10. Qc6+ Bd7 11. Qd5 c4', eval: 'b', text: '白后吃回 d4 兵之後，黑方 ...c5、...c4 用兵把 b3 的象圍住：象沒有退路，黑方會贏下一個子。教訓：用后吃兵前，先看自己的象有沒有路走。' },
    ],
    mistakes: [
      { title: '交換變例裡太早吃 e5：5.Nxe5?', line: '1. e4 e5 2. Nf3 Nc6 3. Bb5 a6 4. Bxc6 dxc6 5. Nxe5 Qd4 6. Nf3 Qxe4+', eval: '=', text: '馬換象之後 e5 看起來沒人保護，但 5.Nxe5? Qd4! 同時攻擊 e5 的馬和 e4 的兵（雙重攻擊），黑方把兵拿回來，還將軍搶到節奏，白方什麼都沒賺到。這也是為什麼主線白方先易位，之後 Nxe5 才是真的威脅。' },
      { title: '同樣的道理：主線 4.Ba4 之後還不能 Bxc6', line: '1. e4 e5 2. Nf3 Nc6 3. Bb5 a6 4. Ba4 Nf6 5. Bxc6 dxc6 6. Nxe5 Qd4', eval: '=', text: '還沒易位前換馬吃兵，黑方 ...Qd4 一樣能叉住 e5 和 e4（這裡還多了 f2），白方得不到好處。' },
    ],
  },
  {
    id: 'sicilian', name: '西西里防禦', en: 'Sicilian Defense', eco: 'B20–B99', side: 'b',
    main: '1. e4 c5 2. Nf3 d6 3. d4 cxd4 4. Nxd4 Nf6 5. Nc3 a6',
    notes: {
      2: '...c5 不對稱地控制 d4，不讓白方輕鬆擁有兩個中心兵。',
      5: 'd4 打開中心。',
      6: '黑方用 c 兵換掉白方的 d 兵：黑方多一個中心兵（e、d 兵），還有半開放的 c 線。',
      8: '...Nf6 攻擊 e4，逼白方用 Nc3 保護。',
      10: '...a6（Najdorf 變例）：不讓白方的馬或象跳到 b5，準備 ...e5 或 ...e6、...b5。',
    },
    purpose: [
      '不對稱的結構：雙方很常異側易位，互相用兵衝對方的王，局面很銳利。',
      '黑方的長期優勢：多一個中心兵、半開放的 c 線（車放 c8 給 c3、c2 壓力）。',
      '白方的優勢：發展領先、空間大，常常在王翼直接攻擊。',
    ],
    lines: [
      { name: '龍式變例（Dragon）南斯拉夫攻擊', eco: 'B76–B79', moves: '1. e4 c5 2. Nf3 d6 3. d4 cxd4 4. Nxd4 Nf6 5. Nc3 g6 6. Be3 Bg7 7. f3 O-O 8. Qd2 Nc6 9. Bc4', text: '黑方把象放在 g7 長對角線；白方長易位後用 h4–h5、Bh6 直接打開 h 線攻擊。' },
      { name: 'Sveshnikov 變例', eco: 'B33', moves: '1. e4 c5 2. Nf3 Nc6 3. d4 cxd4 4. Nxd4 Nf6 5. Nc3 e5 6. Ndb5 d6 7. Bg5 a6 8. Na3 b5', text: '黑方接受 d5 的弱格，換來積極的子力和 ...f5 的反擊。' },
      { name: 'Alapin（2.c3）', eco: 'B22', moves: '1. e4 c5 2. c3 Nf6 3. e5 Nd5 4. d4 cxd4 5. Nf3 Nc6 6. cxd4 d6', text: '白方用 c3 準備 d4，避開大量理論；黑方用 ...Nf6、...d5 等方式立刻打擊中心。' },
    ],
    tactics: [
      { title: 'Sveshnikov 裡的 Nd6+ 威脅', line: '1. e4 c5 2. Nf3 Nc6 3. d4 cxd4 4. Nxd4 Nf6 5. Nc3 e5 6. Ndb5', eval: '=', text: '黑方 ...e5 之後 d6 格變弱：白方 6.Ndb5 威脅 7.Nd6+ 將軍兼攻擊 f8 的象（雙重攻擊）。所以黑方要立刻 6...d6 把這格擋住。' },
      { title: '西伯利亞陷阱（Smith-Morra 棄兵）', line: '1. e4 c5 2. d4 cxd4 3. c3 dxc3 4. Nxc3 Nc6 5. Nf3 e6 6. Bc4 Qc7 7. O-O Nf6 8. Qe2 Ng4 9. h3 Nd4 10. Nxd4 Qh2#', eval: 'b', text: '黑后在 c7、馬在 g4 都瞄準 h2。白方 9.h3?? 想趕馬，黑方 ...Nd4! 先趕走 e2 的后（也打開 c7–h2 的斜線），白方吃馬後 Qh2# 將死。' },
    ],
    mistakes: [
      { title: '...e5 之後忘了 d6 格', line: '1. e4 c5 2. Nf3 Nc6 3. d4 cxd4 4. Nxd4 Nf6 5. Nc3 e5 6. Ndb5 a6 7. Nd6+ Bxd6 8. Qxd6', eval: 'w', text: '6...a6? 想趕馬，但白馬直接跳 d6 將軍，黑方只好用好象換掉它；白后坐在 d6，黑方的黑格全空了、也很難易位。...e5 之後 d6 是弱格，要先 6...d6 擋住。' },
      { title: '西伯利亞陷阱：白方 9.h3??', line: '1. e4 c5 2. d4 cxd4 3. c3 dxc3 4. Nxc3 Nc6 5. Nf3 e6 6. Bc4 Qc7 7. O-O Nf6 8. Qe2 Ng4 9. h3', eval: 'b', text: '看起來只是趕馬，其實讓黑方 ...Nd4! 之後 Qh2#。h2 被后和馬同時瞄準時，要先處理 c7–h2 這條斜線（例如 h3 前先 Rd1 或 g3）。' },
    ],
  },
  {
    id: 'french', name: '法蘭西防禦', en: 'French Defense', eco: 'C00–C19', side: 'b',
    main: '1. e4 e6 2. d4 d5 3. Nc3 Bb4 4. e5 c5 5. a3 Bxc3+ 6. bxc3 Ne7',
    notes: {
      2: '...e6 準備 ...d5，用兵挑戰 e4。',
      4: '...d5：攻擊 e4。',
      6: '...Bb4（Winawer 變例）：牽制 c3 的馬，間接攻擊 e4。',
      7: 'e5 搶空間，黑方 f6 的馬不能用。',
      8: '...c5：法蘭西防禦最重要的反擊——打擊白方兵鏈的底部 d4。',
      11: '黑方用黑格象換掉 c3 馬，白方得到雙象但出現疊兵。',
    },
    purpose: [
      '很穩的防禦：先讓白方建立中心，再用 ...c5 和 ...f6 從兩邊打擊兵鏈。',
      '典型結構：白方 e5–d4 兵鏈、王翼空間大；黑方在后翼反擊。',
      '最大的煩惱：c8 的象被自己 e6 的兵擋住（「壞象」），要找機會用 ...b6、...Ba6 或 ...Bd7–b5 換掉它。',
    ],
    lines: [
      { name: '推進變例（Advance）', eco: 'C02', moves: '1. e4 e6 2. d4 d5 3. e5 c5 4. c3 Nc6 5. Nf3 Qb6 6. a3', text: '白方直接 e5 搶空間；黑方 ...c5、...Nc6、...Qb6 三個子一起攻擊 d4。' },
      { name: 'Tarrasch 變例（3.Nd2）', eco: 'C03–C09', moves: '1. e4 e6 2. d4 d5 3. Nd2 c5 4. exd5 exd5 5. Ngf3 Nc6 6. Bb5', text: '白方用 Nd2 避開 ...Bb4 的牽制。黑方常常接受 d5 孤兵，換來活躍的子力。' },
      { name: '古典變例（3...Nf6）', eco: 'C11–C14', moves: '1. e4 e6 2. d4 d5 3. Nc3 Nf6 4. Bg5 Be7 5. e5 Nfd7 6. Bxe7 Qxe7 7. f4', text: '白方用 e5 把 f6 的馬趕走，f4 支撐兵鏈，準備王翼攻擊。' },
      { name: '交換變例（Exchange）', eco: 'C01', moves: '1. e4 e6 2. d4 d5 3. exd5 exd5 4. Bd3 Nc6 5. c3 Bd6', text: '對稱結構，黑方的 c8 象馬上就自由了；局面平穩。' },
    ],
    tactics: [
      { title: '推進變例的陷阱：Bb5+ 閃擊贏后', line: '1. e4 e6 2. d4 d5 3. e5 c5 4. c3 Nc6 5. Nf3 Qb6 6. Bd3 cxd4 7. cxd4 Nxd4 8. Nxd4 Qxd4 9. Bb5+', eval: 'w', text: '黑方貪吃 d4：8...Qxd4?? 之後 9.Bb5+！象將軍，同時讓開 d 線，d1 的白后直接攻擊 d4 的黑后（閃擊）。黑方只能擋將軍，后就被吃掉。所以黑方在吃 d4 前要先 7...Bd7。' },
      { title: 'Winawer：白后攻擊 g7', line: '1. e4 e6 2. d4 d5 3. Nc3 Bb4 4. e5 c5 5. a3 Bxc3+ 6. bxc3 Ne7 7. Qg4', eval: '=', text: '黑方的黑格象已經換掉，g7 只剩王在保護。白方 Qg4 立刻攻擊 g7，黑方要決定是 ...Qc7 反擊、...Kf8，還是 ...O-O。' },
    ],
    mistakes: [
      { title: '推進變例：還沒 ...Bd7 就吃 d4', line: '1. e4 e6 2. d4 d5 3. e5 c5 4. c3 Nc6 5. Nf3 Qb6 6. Bd3 cxd4 7. cxd4 Nxd4 8. Nxd4 Qxd4', eval: 'w', text: '這一步之後白方有 9.Bb5+ 閃擊贏后。正確順序是 7...Bd7（先擋住 b5–e8 這條線），之後再考慮吃兵。' },
      { title: '把 c8 的象忘在家裡', line: '1. e4 e6 2. d4 d5 3. e5 c5 4. c3 Nc6 5. Nf3 Bd7', eval: '=', text: '法蘭西防禦常見的問題是 c8 的象沒事做。這裡 ...Bd7 是合理的開始，之後可以 ...Qb6、...Rc8，或找機會 ...Bb5 換掉白方的好象。' },
    ],
  },
  {
    id: 'carokann', name: '卡羅—康防禦', en: 'Caro-Kann Defense', eco: 'B10–B19', side: 'b',
    main: '1. e4 c6 2. d4 d5 3. Nc3 dxe4 4. Nxe4 Bf5 5. Ng3 Bg6 6. h4 h6 7. Nf3 Nd7 8. h5 Bh7 9. Bd3 Bxd3 10. Qxd3',
    notes: {
      2: '...c6 準備 ...d5，跟法蘭西防禦很像，但 c8 的象還能出來。',
      6: '黑方用 d 兵換 e4 兵。',
      8: '...Bf5：先把象放出去，再走 ...e6——這是卡羅—康和法蘭西最大的差別。',
      9: 'Ng3 攻擊象，趕它走。',
      11: 'h4：威脅 h5 把象逼走、在王翼搶空間。',
      12: '...h6：給象留 h7 的退路。',
      18: '...Bxd3：換掉白方的好象，黑方的結構很穩。',
    },
    purpose: [
      '穩固的防禦：兵結構健康（c6、d5 或 c6、e6），殘局常常比較舒服。',
      '先把 c8 的象放出去，再用 ...e6 鞏固，不會有法蘭西的「壞象」問題。',
      '計畫：完成發展後用 ...c5 或 ...e5 打擊中心。',
    ],
    lines: [
      { name: '推進變例（Advance）', eco: 'B12', moves: '1. e4 c6 2. d4 d5 3. e5 Bf5 4. Nf3 e6 5. Be2 c5', text: '白方 e5 搶空間；黑方先出象，再 ...e6、...c5 打擊 d4。' },
      { name: '交換變例（Exchange）', eco: 'B13', moves: '1. e4 c6 2. d4 d5 3. exd5 cxd5 4. Bd3 Nc6 5. c3 Nf6 6. Bf4', text: '對稱結構，白方多半想用 Qb3 攻擊 b7、或王翼慢慢攻擊。' },
      { name: 'Panov 攻擊', eco: 'B14', moves: '1. e4 c6 2. d4 d5 3. exd5 cxd5 4. c4 Nf6 5. Nc3 e6 6. Nf3', text: '白方用 c4 製造孤兵結構，換來積極的子力。' },
    ],
    tactics: [
      { title: '悶殺陷阱：Nd6#', line: '1. e4 c6 2. d4 d5 3. Nc3 dxe4 4. Nxe4 Nd7 5. Qe2 Ngf6 6. Nd6#', eval: 'w', text: '黑方 5...Ngf6?? 看起來在發展，但 e7 兵被 e2 的白后牽制住（後面是王），白馬跳到 d6 將軍沒人能吃，王也被自己的子圍住——悶殺。' },
    ],
    mistakes: [
      { title: '5...Ngf6??（被悶殺）', line: '1. e4 c6 2. d4 d5 3. Nc3 dxe4 4. Nxe4 Nd7 5. Qe2 Ngf6', eval: 'w', text: '白后在 e2 時，e7 兵被牽制，d6 格沒人能守。這裡應該先 5...Ndf6 或 5...e6。' },
      { title: '交換變例裡忽略 b7', line: '1. e4 c6 2. d4 d5 3. exd5 cxd5 4. Bd3 Nc6 5. c3 Nf6 6. Bf4 Bg4 7. Qb3', eval: '=', text: '黑象出去之後 b7 只剩少數子保護，白方 Qb3 同時攻擊 b7 和 d5，黑方要準備 ...Qd7 或 ...Na5 應對。出象前先想想 b7 的安全。' },
    ],
  },
  {
    id: 'qgd', name: '后翼棄兵', en: "Queen's Gambit", eco: 'D06–D69', side: 'w',
    main: '1. d4 d5 2. c4 e6 3. Nc3 Nf6 4. Bg5 Be7 5. e3 O-O 6. Nf3 Nbd7 7. Rc1 c6 8. Bd3 dxc4 9. Bxc4 Nd5',
    notes: {
      3: 'c4：用旁邊的 c 兵換黑方的中心 d 兵。說是「棄兵」，其實黑方很難守住多的兵。',
      4: '...e6（后翼棄兵拒絕，QGD）：守住 d5，結構很穩，但 c8 的象暫時被擋住。',
      7: 'Bg5 牽制 f6 的馬，增加對 d5 的壓力。',
      13: 'Rc1：車放在可能打開的 c 線上。',
      16: '黑方算好時機才吃 c4，讓白象多走一步。',
      18: '...Nd5！（Capablanca 的解放法）：換掉一些子，讓局面輕鬆。',
    },
    purpose: [
      '白方用 c4 挑戰 d5，目標是拿下中心或讓黑方的結構出現弱點。',
      '黑方要決定：守住 d5（QGD、斯拉夫），還是接受棄兵、之後再還（QGA）。',
      '典型計畫：白方「少數兵攻擊」（b4–b5 打擊黑方后翼）、或中心 e4 突破。',
    ],
    lines: [
      { name: '后翼棄兵接受（QGA）', eco: 'D20–D29', moves: '1. d4 d5 2. c4 dxc4 3. Nf3 Nf6 4. e3 e6 5. Bxc4 c5 6. O-O a6', text: '黑方先吃兵、之後還回去，換來快速發展和 ...c5 打擊中心。' },
      { name: '斯拉夫防禦（Slav）', eco: 'D10–D19', moves: '1. d4 d5 2. c4 c6 3. Nf3 Nf6 4. Nc3 dxc4 5. a4 Bf5 6. e3 e6 7. Bxc4 Bb4', text: '用 ...c6 守 d5，c8 的象可以先出到 f5。' },
      { name: '交換變例（少數兵攻擊）', eco: 'D35–D36', moves: '1. d4 d5 2. c4 e6 3. Nc3 Nf6 4. cxd5 exd5 5. Bg5 c6 6. e3 Be7 7. Bd3', text: '白方先換掉 d5，之後用 b4–b5（兩個兵打三個兵）在后翼製造弱點。' },
    ],
    tactics: [
      { title: '大象陷阱（Elephant Trap）', line: '1. d4 d5 2. c4 e6 3. Nc3 Nf6 4. Bg5 Nbd7 5. cxd5 exd5 6. Nxd5 Nxd5 7. Bxd8 Bb4+ 8. Qd2 Bxd2+ 9. Kxd2 Kxd8', eval: 'b', text: '白方以為 d5 的馬被牽制（Nf6 後面是后），6.Nxd5?? 吃兵。黑方 ...Nxd5! 送后，白象吃后後，...Bb4+ 將軍逼白后擋、再換掉——算下來黑方多一個子。' },
    ],
    mistakes: [
      { title: '白方 6.Nxd5??（掉進大象陷阱）', line: '1. d4 d5 2. c4 e6 3. Nc3 Nf6 4. Bg5 Nbd7 5. cxd5 exd5 6. Nxd5', eval: 'b', text: 'f6 的馬其實沒有被真的牽制——它可以走，因為黑方之後有 ...Bb4+ 的將軍拿回后。吃兵前要先算對手的「強迫手」（將軍、吃子）。' },
      { title: '黑方想守住多的兵：3...b5?', line: '1. d4 d5 2. c4 dxc4 3. e3 b5 4. a4 c6 5. axb5 cxb5 6. Qf3', eval: 'w', text: '接受棄兵後硬要守 c4，a 線、長對角線都打開了：6.Qf3 同時攻擊 a8 的車，黑方會丟子。QGA 的重點是「先吃、之後還」，不是硬守。' },
    ],
  },
  {
    id: 'london', name: '倫敦系統', en: 'London System', eco: 'D00–D02、A46–A48', side: 'w',
    main: '1. d4 d5 2. Bf4 Nf6 3. e3 e6 4. Nf3 c5 5. c3 Nc6 6. Nbd2 Bd6 7. Bg3 O-O 8. Bd3',
    notes: {
      3: 'Bf4：先把黑格象放到兵鏈外面（之後 e3 不會擋住它）。',
      5: 'e3：建立 c3–d4–e3 的「金字塔」。',
      9: 'c3 守住 d4，也給后留 b3 的路。',
      11: 'Nbd2：保護 f3 和 e4，之後可以 Ne5。',
      13: 'Bg3：不換象，保持對 e5 的控制。',
      15: '幾乎不管黑方怎麼下，白方都是這套佈置——這就是「系統」的意思。',
    },
    purpose: [
      '同一套佈置對付幾乎所有黑方的下法，背的東西少、計畫清楚。',
      '結構非常穩，很難一開局就輸，適合想把時間花在中盤的人。',
      '典型計畫：Ne5 + f4 加強中心，或 h4、Qf3 在王翼攻擊；黑方則多半用 ...c5、...Qb6 給 b2、d4 壓力。',
    ],
    lines: [
      { name: '對付印度式（...g6）', eco: 'A48', moves: '1. d4 Nf6 2. Nf3 g6 3. Bf4 Bg7 4. e3 O-O 5. Be2 d6 6. h3', text: '黑方用 ...g6 長對角線時，白方 h3 給象留後路，對付 ...Nh5。' },
      { name: 'Jobava 倫敦（2.Nc3）', eco: 'D00', moves: '1. d4 d5 2. Nc3 Nf6 3. Bf4 e6 4. e3 c5 5. Nb5', text: '更積極的版本：馬跳 b5 威脅 c7。' },
      { name: '黑方 ...Qb6 攻擊 b2', eco: 'D00', moves: '1. d4 d5 2. Bf4 Nf6 3. e3 c5 4. c3 Nc6 5. Nd2 Qb6 6. Qb3 c4 7. Qc2', text: '黑后攻擊 b2，白方用 Qb3 換后或擋住，再退到 c2。' },
    ],
    tactics: [
      { title: '...Qb6：同時盯 b2 與 d4', line: '1. d4 d5 2. Bf4 c5 3. e3 Nc6 4. Nf3 Qb6', eval: '=', text: '黑方的后、c5 兵、c6 馬一起攻擊 d4，后同時看著 b2。白方常用 5.Qb3（換后）或 5.Nc3 處理；Bf4 一出去，b2 就少了象保護，這是倫敦系統要注意的地方。' },
      { title: '...Nh5 追象：預留退路', line: '1. d4 Nf6 2. Bf4 d6 3. Nf3 Nh5', eval: '=', text: '黑馬攻擊 f4 的象，想換掉這隻好象。白方可以 Bg5、Bg3（換掉也沒關係，h 線會打開），或事先走 h3 讓象有 h2 可以退。' },
    ],
    mistakes: [
      { title: '忘了 b2 兵', line: '1. d4 d5 2. Bf4 c5 3. e3 Qb6 4. Nf3 Qxb2', eval: '=', text: '白方沒處理 ...Qb6，黑后吃掉 b2 兵。雖然白方有 Nbd2、Rb1 的發展補償，但對大多數人來說只是白白丟兵。早點走 Qb3、Qc1 或 Nc3 擋住。' },
      { title: '貪吃 b7：Qxb7? Nb4!', line: '1. d4 d5 2. Bf4 Nf6 3. e3 Bf5 4. c4 e6 5. Qb3 Nc6 6. Qxb7 Nb4', eval: '=', text: 'Qb3 攻擊 b7 是常見手法，但黑方 ...Nc6 之後還去吃 b7，黑馬跳 b4 威脅 Nc2+（同時攻擊王和 a1 的車）。白方得花好幾步處理威脅，多吃的兵換來的是落後的發展，引擎認為反而是黑方比較好下。先算清楚對手的反擊再吃兵。' },
    ],
  },
  {
    id: 'kid', name: '古印度防禦', en: "King's Indian Defense", eco: 'E60–E99', side: 'b',
    main: '1. d4 Nf6 2. c4 g6 3. Nc3 Bg7 4. e4 d6 5. Nf3 O-O 6. Be2 e5 7. O-O Nc6 8. d5 Ne7',
    notes: {
      2: '...Nf6：先不佔中心。',
      4: '...g6：準備把象放在 g7 的長對角線上（側翼出象）。',
      7: '白方建立 c4–d4–e4 三個兵的大中心——黑方故意讓它建。',
      12: '...e5：古印度的核心反擊，直接挑戰 d4。',
      15: 'd5：白方鎖住中心，雙方各在一翼進攻。',
      16: '...Ne7（Mar del Plata 變例）：馬讓開，準備 ...Nd7（或 ...Ne8）、...f5 衝王翼。',
    },
    purpose: [
      '「超現代」思路：先讓白方建立大中心，之後用 ...e5 或 ...c5 打擊它。',
      '中心封閉後，黑方在王翼用兵衝鋒（...f5–f4–g5–g4），白方在后翼（c5、b4）突破——典型的「比速度」。',
      'g7 的象是黑方最重要的子，中心打開後它會非常強。',
    ],
    lines: [
      { name: 'Sämisch 變例（5.f3）', eco: 'E80–E89', moves: '1. d4 Nf6 2. c4 g6 3. Nc3 Bg7 4. e4 d6 5. f3 O-O 6. Be3 e5 7. d5', text: 'f3 鞏固 e4，白方常常長易位後在王翼推兵攻擊。' },
      { name: '四兵攻擊（Four Pawns）', eco: 'E76–E79', moves: '1. d4 Nf6 2. c4 g6 3. Nc3 Bg7 4. e4 d6 5. f4 O-O 6. Nf3 c5 7. d5 e6', text: '白方用四個兵佔中心，黑方用 ...c5、...e6 立刻反擊，局面很銳利。' },
      { name: '側翼變例（Fianchetto）', eco: 'E60–E69', moves: '1. d4 Nf6 2. c4 g6 3. Nf3 Bg7 4. g3 O-O 5. Bg2 d6 6. O-O Nbd7 7. Nc3 e5', text: '白方也把象放在長對角線，局面比較安靜、偏向位置性。' },
    ],
    tactics: [
      { title: '換后後吃 e5？小心 ...Nxe4', line: '1. d4 Nf6 2. c4 g6 3. Nc3 Bg7 4. e4 d6 5. Nf3 O-O 6. Be2 e5 7. dxe5 dxe5 8. Qxd8 Rxd8 9. Nxe5 Nxe4 10. Nxe4 Bxe5', eval: '=', text: '9.Nxe5 吃兵後，黑方馬上 ...Nxe4!：白方如果吃回馬，g7 的象就吃掉 e5 的馬，兵拿回來了。長對角線上的象常常讓這種「看起來白吃的兵」吃不得。' },
      { title: 'Mar del Plata：王翼衝鋒', line: '1. d4 Nf6 2. c4 g6 3. Nc3 Bg7 4. e4 d6 5. Nf3 O-O 6. Be2 e5 7. O-O Nc6 8. d5 Ne7 9. Ne1 Nd7 10. Nd3 f5', eval: '=', text: '中心鎖住後，黑方用 ...Nd7、...f5（之後 ...f4、...g5、...g4）在王翼進攻；白方則準備 c5 在后翼突破。誰的攻擊比較快，誰就佔上風。' },
    ],
    mistakes: [
      { title: '白方 9.Nxe5 吃兵', line: '1. d4 Nf6 2. c4 g6 3. Nc3 Bg7 4. e4 d6 5. Nf3 O-O 6. Be2 e5 7. dxe5 dxe5 8. Qxd8 Rxd8 9. Nxe5', eval: '=', text: '吃了 e5 兵，但 e4 兵也不穩：黑方 ...Nxe4 之後兵就還回來了，白方沒賺到。交換變例裡白方通常走 9.Bg5 牽制。' },
      { title: '黑方太被動，讓白方輕鬆擴張', line: '1. d4 Nf6 2. c4 g6 3. Nc3 Bg7 4. e4 d6 5. Nf3 O-O 6. Be2 Nbd7 7. O-O a6 8. Re1 Re8', eval: 'w', text: '古印度讓白方建中心，是為了之後打擊它。如果一直不走 ...e5 或 ...c5，白方會毫無代價地擁有大中心和空間。' },
    ],
  },
];
