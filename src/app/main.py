import modules
import secrets
import uuid


from flask import Flask, render_template, redirect, url_for
from flask_bootstrap import Bootstrap5
from flask_wtf import FlaskForm, CSRFProtect
from werkzeug.utils import secure_filename

from wtforms import SubmitField, StringField, FileField
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
    submit = SubmitField('Submit')

# Homepage and where most of the work happens. This also calls the API for text generation and embedding, then publishes them to a Pub/Sub topic before directing users to their response


@app.route('/', methods=['GET', 'POST'])
def index():
    form = initialInputs()
    if form.validate_on_submit():
        prompt_tone = form.prompt_tone.data.replace(
            '"', '\"').replace("'", "\'")
        prompt_purpose = form.prompt_purpose.data.replace(
            '"', '\"').replace("'", "\'")
        prompt_notes = form.prompt_notes.data.replace(
            '"', '\"').replace("'", "\'")
        input_prompt = f"""
        Write the body of a marketing email from Cymbal Retail that will {prompt_purpose}.
        The subject of the email should start with \'Subject:\' and the body of the email should start with \'Body:\'.
        Write it in the tone of {prompt_tone}.
        Make sure to incude {prompt_notes}
        """
        prompt_embed = modules.get_text_embeddings(input_prompt)
        modules.publish_prompt_pubsub(session_id, input_prompt, prompt_embed)
        output = modules.get_response(input_prompt)
        response_text = output.text.replace("\n", " ").replace("\r", "")
        safety_attributes = output.safety_attributes
        response_embed = modules.get_text_embeddings(response_text)
        modules.publish_response_pubsub(session_id, response_text,
                                        safety_attributes, response_embed)
        return redirect(url_for('review', response=response_text))
    else:
        message = "Invalid inputs. Try again"
        return render_template('index.html', form=form)

# Route users to the model response to view their email


@app.route('/review/<response>')
def review(response):
    if response is None:
        return render_template('500.html'), 500
    else:
        x = response.split("Subject:")[1]
        x = x.split("Body:")
        email_subject = x[0].strip()
        email_body = x[1].strip()
        return render_template('review.html', email_subject=email_subject, email_body=email_body)

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
