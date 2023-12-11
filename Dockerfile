#syntax=docker/dockerfile:1.4

# This Dockerfile uses the root project folder as context.

# Dockerfile global arguments
ARG PYTHON_VERSION='3.10'

# --
# Upstream images

FROM python:${PYTHON_VERSION}-slim AS python_upstream


# --
# App base image

FROM python_upstream AS app_base

WORKDIR /app

# Install app requirements
COPY --link ./requirements_versions.txt .
RUN pip install --no-cache-dir -r requirements_versions.txt && \
	# Clean up
	pip cache purge && \
	rm -rf /root/.cache/pip

# Install additional runtime requirements
RUN pip install --no-cache-dir \
		torch==2.1.0 \
		torchvision==0.16.0 \
		&& \
	# Clean up
	pip cache purge && \
	rm -rf /root/.cache/pip
RUN apt-get update && \
	apt-get install -y --no-install-recommends \
		libgl1 \
		libglib2.0-0 \
		&& \
	# Clean up
	apt-get clean && \
	rm -rf /var/lib/apt/lists/*

# Set exposed port
ARG PORT=80
ENV PORT=${PORT}


# --
# Prod build image

FROM app_base AS app_prod

# Mount source code as volume
VOLUME /app

# Expose port
EXPOSE ${PORT}

CMD [ "/bin/sh", "-c", "python entry_with_update.py --listen \"0.0.0.0\" --port \"${PORT}\"" ]
