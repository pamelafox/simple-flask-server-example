import base64
import json

from flask import Flask, render_template, request

# Create a flask app
app = Flask(
  __name__,
  template_folder='templates',
  static_folder='static'
)

@app.get('/')
def index():
  return render_template('index.html')

# Extract the username for display from the base64 encoded header
# X-MS-CLIENT-PRINCIPAL from the 'name' claim.
#
# Fallback to `default_username` if the header is not present.
def extract_username(headers, default_username="You"):
    if "X-MS-CLIENT-PRINCIPAL" not in headers:
        return default_username

    token = json.loads(base64.b64decode(headers.get("X-MS-CLIENT-PRINCIPAL")))
    claims = {claim["typ"]: claim["val"] for claim in token["claims"]}
    return claims.get("name", default_username)

@app.get('/hello')
def hello():
  return render_template('hello.html', name=extract_username(request.headers))

@app.errorhandler(404)
def handle_404(e):
    return '<h1>404</h1><p>File not found!</p><img src="https://httpcats.com/404.jpg" alt="cat in box" width=400>', 404


if __name__ == '__main__':
  # Run the Flask app
  app.run(host='0.0.0.0', debug=True, port=8080)