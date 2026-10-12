S="$(cd "$(dirname "$0")" && pwd)"
REPO="$(cd "$S/../.." && pwd)"
export S REPO
mkdir -p "$S/site"
cd $S
curl -s -o /dev/null http://127.0.0.1:8766/ || (cd site && nohup python3 -m http.server 8766 >/dev/null 2>&1 &)
curl -s -o /dev/null http://127.0.0.1:8770/ || (cd "$REPO" && nohup python3 -m http.server 8770 >/dev/null 2>&1 &)
curl -s -o /dev/null http://127.0.0.1:9000/ || (nohup node srv.js > peer.log 2>&1 &)
grep -q up broker.log 2>/dev/null && ss -ltn 2>/dev/null | grep -q ':9001' || (nohup node broker.js > broker.log 2>&1 &)
sleep 1.5
python3 -c "
import socket
for p in (8766,8770,9000,9001):
    s=socket.socket(); r=s.connect_ex(('127.0.0.1',p)); print(p,'up' if r==0 else 'DOWN'); s.close()"
