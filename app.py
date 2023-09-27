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


@app.get('/index.html')
def index2():
  return render_template('index.html')


@app.get('/about')
def about():
  return render_template('about.html')


@app.get('/hello') # hello?firstname=Pamela query param
def hello():
  return render_template('hello.html', name=request.args.get('firstname'))

@app.get('/post/<int:post_id>')
def show_post(post_id):
    # show the post with the given id, the id is an integer
    return f'Post {post_id}'

@app.post('/login')
def process_form():
    username = request.form.get('username')
    password = request.form.get('password')
    # do something very secure with this information
    return f'Logged in Username: {username}'

@app.errorhandler(404)
def handle_404(e):
    return '<h1>404</h1><p>File not found!</p><img src="https://httpcats.com/404.jpg" alt="cat in box" width=400>', 404


if __name__ == '__main__':
  # Run the Flask app
  app.run(host='0.0.0.0', debug=True, port=8080)