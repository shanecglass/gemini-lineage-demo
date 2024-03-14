# Use an official lightweight Python image.
FROM python:3.10.7-slim

RUN apt-get update
RUN apt-get -y install git

# Copy local code to the container image.
RUN mkdir ./app
WORKDIR /home/ubuntudocker/app

COPY main.py .
COPY modules.py .
COPY requirements.txt .
COPY ./templates /home/ubuntudocker/app/templates


# Install dependencies into this container so there's no need to
# install anything at container run time.
RUN pip install -r requirements.txt

# Service must listen to $PORT environment variable.
# This default value facilitates local development.
ENV PORT 5000

# Run the web service on container startup. Here you use the gunicorn
# server, with one worker process and 8 threads. For environments
# with multiple CPU cores, increase the number of workers to match
# the number of cores available.
CMD exec gunicorn --bind 0.0.0.0:$PORT --workers 1 --threads 8 --timeout 0 main:app
