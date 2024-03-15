import modules
import os
import secrets
import uuid

from flask import Flask, flash, request, render_template, redirect, url_for
from flask_bootstrap import Bootstrap5
from flask_wtf import FlaskForm, CSRFProtect

from werkzeug.utils import secure_filename

from wtforms import SubmitField, StringField, FileField, TextAreaField
from wtforms.validators import DataRequired

app = Flask(__name__, template_folder='./templates')
foo = secrets.token_urlsafe(16)
app.secret_key = foo
app.config['MAX_CONTENT_LENGTH'] = 64 * 1000 * 1000
bootstrap = Bootstrap5(app)
csrf = CSRFProtect(app)
session_id = str(uuid.uuid4())

upload_folder = "./user_image"
ALLOWED_EXTENSIONS = ['png', 'jpg', 'jpeg']


def allowed_file(filename):
    return '.' in filename and \
        filename.rsplit('.', 1)[1].lower() in ALLOWED_EXTENSIONS


class initialInputs(FlaskForm):
    user_image = FileField(
        'Upload a picture of your product. Image must be a PNG or JPG file and smaller than 64 MBs.', validators=[DataRequired()])
    user_email = StringField(
        'Enter the email associated with your purchase', validators=[DataRequired()])
    order_number = StringField(
        'Enter your order number', validators=[DataRequired()])
    additional_notes = TextAreaField(
        'Enter any additional notes you would like to include')
    submit = SubmitField('Submit')

# Homepage and where most of the work happens. This also calls the API for text generation and embedding, then publishes them to a Pub/Sub topic before directing users to their response


@app.route('/', methods=['GET', 'POST'])
def index():
    form = initialInputs()
    if form.validate_on_submit():
        user_email = form.user_email.data.replace(
            '"', '\"').replace("'", "\'")
        order_number = form.order_number.data.replace(
            '"', '\"').replace("'", "\'")
        review_text = form.additional_notes.data.replace(
            '"', '\"').replace("'", "\'")
        form_data = [user_email, order_number, review_text]
        model_inputs = modules.get_required_inputs(user_email, order_number)
        if model_inputs["eligible"][0] is False:
            return render_template(url_for('ineligible.html'))
        else:
            if request.method == 'POST':
                if 'file' not in request.files:
                    flash('No file part')
                    return redirect(request.url)
                file = request.files['file']
                # If the user does not select a file, the browser submits an
                # empty file without a filename.
                if file.filename == '':
                    flash('No selected file')
                    return redirect(request.url)
                if file and allowed_file(file.filename):
                    filename = secure_filename(file.filename)
                    image_path = os.path.join(
                        app.config['UPLOAD_FOLDER'], filename)
                    file.save(image_path)
                modules.call_llm(model_inputs, form_data, image_path)
                return redirect(url_for('review.html'))
            else:
                return render_template('index.html', form=form)

# Route users to the model response to view their email


@app.route('/review/<response>')
def review(response):
    if response is None:
        return render_template('500.html'), 500
    else:
        return render_template('review.html')

# 2 routes to handle common errors


@app.errorhandler(404)
def page_not_found(e):
    return render_template('404.html'), 404


@app.errorhandler(500)
def internal_server_error(e):
    return render_template('500.html'), 500


# keep this as is
if __name__ == '__main__':
    app.run(debug=True)
