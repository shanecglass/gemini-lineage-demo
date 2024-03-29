# import json
import modules
import os
import secrets
import tempfile

from flask import Flask, render_template, redirect, url_for, request
from flask_bootstrap import Bootstrap5
from flask_uploads import UploadSet, IMAGES, configure_uploads
from flask_wtf import FlaskForm, CSRFProtect
from flask_wtf.file import FileField, FileAllowed, FileRequired

from wtforms import SubmitField, StringField, TextAreaField, SelectField
from wtforms.validators import DataRequired

# Flask setup and configuration

upload_folder = tempfile.mkdtemp()
images = UploadSet('images', IMAGES)

app = Flask(__name__, template_folder='./templates')
foo = secrets.token_urlsafe(32)
app.secret_key = foo
app.config['MAX_CONTENT_LENGTH'] = 64 * 1000 * 1000
app.config['UPLOADED_IMAGES_DEST'] = upload_folder
app.config['SESSION_COOKIE_DOMAIN'] = None

bootstrap = Bootstrap5(app)
csrf = CSRFProtect(app)
csrf.init_app(app)


configure_uploads(app, (images,))


class initialInputs(FlaskForm):
    user_image = FileField(
        'Upload a picture of your product. Image must be a PNG file and smaller than 64 MBs.',
        validators=[FileRequired(), FileAllowed(images, 'Hey Sport, Images only!')])
    user_email = StringField(
        'Enter the email associated with your purchase', validators=[DataRequired(message='Woah, slow down Champ. You forgot to enter your email!')])
    order_number = StringField(
        'Enter your order number', validators=[DataRequired(message='Woah, slow down Pal. You forgot to enter your order ID!')])
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
        user_image = form.user_image.data
        image_path = os.path.join(upload_folder, "customer_image.png")
        user_image.save(image_path)
        modules.upload_to_gcs(
            image_path, f"{order_number}_refund_request.png")
        return redirect(url_for('product_select', user_email=user_email, order_number=order_number, review_text=review_text))
    return render_template('index.html', form=form, message=message)

# Route users to the model response to view their confirmation


class productSelect(FlaskForm):
    product_list = SelectField(
        'Please select the product you want to return', coerce=int, validators=[DataRequired()])
    submit = SubmitField('Submit')


@app.route('/product_select', methods=['GET', 'POST'])
def product_select():
    user_email = request.args.get("user_email")
    order_number = request.args.get("order_number")
    review_text = request.args.get("review_text")
    products = modules.products_in_order(order_number)
    form = productSelect()
    form.product_list.choices = [
        (products["product_id"][i], products["product_name"][i]) for i in range(len(products))]
    if form.validate_on_submit():
        product_id = form.product_list.data
        model_inputs = modules.get_required_inputs(
            user_email, order_number, product_id)
        form_inputs = [user_email, order_number, review_text]
        eligible_check = model_inputs["eligible"][0]
        if eligible_check == "True":
            model_response = modules.call_llm(model_inputs, form_inputs)
            print(model_response.lower())
            if model_response.lower() == "no":
                return render_template('ineligible.html'), 200
            else:
                modules.publish_refund_pubsub(
                    str(product_id), model_inputs["product_name"][0], model_inputs["sale_price"][0], order_number, user_email)
                return render_template('review.html', order_number=order_number), 200
        else:
            return render_template('ineligible.html'), 200
    return render_template('product_select.html', form=form)

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
