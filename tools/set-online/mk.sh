S="$(cd "$(dirname "$0")" && pwd)"
REPO="$(cd "$S/../.." && pwd)"
mkdir -p "$S/site"
export S REPO
python3 - <<'PY'
import os
S=os.environ['S']; REPO=os.environ['REPO']
s=open(f'{REPO}/games/game-set.html').read()
s=s.replace("host: '0.peerjs.com',\n                port: 443,","host: '127.0.0.1',\n                port: 9000,").replace("secure: true,","secure: false,",1)
s=s.replace("'wss://broker.emqx.io:8084/mqtt',","'ws://127.0.0.1:9001/mqtt',").replace("'wss://broker.hivemq.com:8884/mqtt'","'ws://127.0.0.1:9999/mqtt'")
open(f'{S}/site/game-set.html','w').write(s)
short=s.replace("deck = shuffle(buildDeck());","deck = shuffle(buildDeck()).slice(0, 18);")
assert short!=s
open(f'{S}/site/short.html','w').write(short)
PY
python3 - <<'PY'
import os
S=os.environ['S']; REPO=os.environ['REPO']
s=open(f'{S}/site/game-set.html').read()
b=s.replace("sdpSemantics: 'unified-plan'","sdpSemantics: 'unified-plan', iceTransportPolicy: 'relay'").replace("'turn:eu-0.turn.peerjs.com:3478',\n                                'turn:us-0.turn.peerjs.com:3478'","'turn:127.0.0.1:1'")
assert b!=s; open(f'{S}/site/blocked.html','w').write(b)
PY
