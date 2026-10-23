"""Local API fixture for real streaming/nonstreaming transport checks. No external requests."""
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
import json
import time

class Handler(BaseHTTPRequestHandler):
    def do_POST(self):
        if self.path != '/v1/chat/completions':
            self.send_error(404)
            return
        body = json.loads(self.rfile.read(int(self.headers['Content-Length'])))
        if body.get('model') not in ['fixture-cat', 'fixture-fail', 'fixture-slow'] or not body.get('messages'):
            self.send_error(400)
            return
        if body.get('model') == 'fixture-fail':
            time.sleep(0.4)
            self.send_error(500)
            return
        if body.get('model') == 'fixture-slow':
            time.sleep(0.8)
        self.send_response(200)
        if body.get('stream'):
            self.send_header('Content-Type', 'text/event-stream')
            self.end_headers()
            for token in ['Hello ', 'from ', 'chubby-', 'cat.']:
                event = ('data: ' + json.dumps({'choices': [{'delta': {'content': token}}]}) + '\n\n').encode()
                # Split network writes in the middle of JSON, not at SSE boundaries.
                half = len(event) // 2
                self.wfile.write(event[:half]); self.wfile.flush()
                time.sleep(0.01)
                self.wfile.write(event[half:]); self.wfile.flush()
            self.wfile.write(b'data: [DONE]\n\n'); self.wfile.flush()
        else:
            self.send_header('Content-Type', 'application/json')
            self.end_headers()
            self.wfile.write(json.dumps({'choices': [{'message': {'role': 'assistant', 'content': 'Hello from chubby-cat.'}}]}).encode())
    def log_message(self, *_):
        pass

if __name__ == '__main__':
    import sys
    port = int(sys.argv[1]) if len(sys.argv) > 1 else 18743
    print(f'Fixture listening on 127.0.0.1:{port}', flush=True)
    ThreadingHTTPServer(('127.0.0.1', port), Handler).serve_forever()
