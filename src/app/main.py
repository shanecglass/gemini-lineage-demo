import modules
import os
import secrets
import tempfile

from flask import Flask, render_template, redirect, url_for
from flask_bootstrap import Bootstrap5
from flask_uploads import UploadSet, IMAGES, configure_uploads
from flask_wtf import FlaskForm, CSRFProtect
from flask_wtf.file import FileField, FileAllowed, FileRequired


from werkzeug.utils import secure_filename

from wtforms import SubmitField, StringField, TextAreaField
from wtforms.validators import DataRequired

# Flask setup and configuration

upload_folder = tempfile.mkdtemp()
images = UploadSet('images', IMAGES)

app = Flask(__name__, template_folder='./templates')
foo = secrets.token_urlsafe(32)
app.secret_key = foo
app.config['MAX_CONTENT_LENGTH'] = 64 * 1000 * 1000
app.config['UPLOADED_IMAGES_DEST'] = upload_folder

bootstrap = Bootstrap5(app)
csrf = CSRFProtect(app)

configure_uploads(app, (images,))


class initialInputs(FlaskForm):
    user_image = FileField(
        'Upload a picture of your product. Image must be a PNG file and smaller than 64 MBs.',
        validators=[FileRequired(), FileAllowed(images, 'Images only!')])
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
    message = ""
    if form.validate_on_submit():
        user_email = form.user_email.data
        order_number = form.order_number.data
        review_text = form.additional_notes.data.strip().strip('"')
        print(review_text)
        user_image = form.user_image.data
        print(user_image)
        filename = secure_filename(user_image.filename)
        print(filename)
        image_path = os.path.join(upload_folder, filename)
        print(image_path)
        user_image.save(image_path)
        print("save successful")
        form_data = [user_email, order_number, review_text]
        model_inputs = modules.get_required_inputs(user_email, order_number)
        print(model_inputs)
        eligible_check = model_inputs["eligible"][0]
        print(eligible_check)
        if eligible_check == "False":
            return render_template('ineligible.html'), 200
        if eligible_check == "True":
            modules.call_llm(model_inputs, form_data, image_path)
            return redirect(url_for('review', order=order_number))
        else:
            message = "Woah there, Sport. Check those inputs and try again."
    return render_template('index.html', form=form, message=message)

# Route users to the model response to view their confirmation


@app.route('/review/<order>')
def review(order):
    return render_template('review.html', order=order)


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
