#!/usr/bin/env python3
from http.server import BaseHTTPRequestHandler, HTTPServer
import subprocess

class Handler(BaseHTTPRequestHandler):
    def do_GET(self):
        if self.path == '/join':
            join_cmd = subprocess.check_output(['microk8s', 'add-node', '--token-ttl', '300']).decode()
            self.send_response(200)
            self.send_header('Content-type', 'text/plain')
            self.end_headers()
            self.wfile.write(join_cmd.encode())

httpd = HTTPServer(('0.0.0.0', 8080), Handler)
httpd.serve_forever()
