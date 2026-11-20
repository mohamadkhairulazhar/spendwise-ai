"""Serve the built demo at its real GitHub Pages subdirectory for browser tests."""
from functools import partial
from http.server import SimpleHTTPRequestHandler, ThreadingHTTPServer


class PagesHandler(SimpleHTTPRequestHandler):
    def do_GET(self):
        if not self.path.startswith('/spendwise-ai/'):
            self.send_error(404)
            return
        self.path = self.path[len('/spendwise-ai'):]
        super().do_GET()


if __name__ == '__main__':
    ThreadingHTTPServer(('127.0.0.1', 8080), partial(
        PagesHandler, directory='build/web')).serve_forever()
