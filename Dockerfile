#syntax=docker/dockerfile:1.4

# This Dockerfile uses the root project folder as context.

# Dockerfile globalarguments
ARG PYTHON_BASE='base'
ARG PYTHON_VERSION='3.10'
ARG CUDA_VERSION='12.1.1'

# --
# Upstream images

FROM python:${PYTHON_VERSION}-slim AS python_upstream
FROM nvidia/cuda:${CUDA_VERSION}-runtime-ubuntu22.04 AS cuda_upstream


# --
# Python Base image

FROM python_upstream AS python_base


# --
# Python CUDA image

FROM cuda_upstream AS python_cuda

ARG PYTHON_VERSION
ARG DEBIAN_FRONTEND='noninteractive'

# Install Python
RUN apt-get update && \
	apt-get install -y --no-install-recommends \
		python${PYTHON_VERSION} \
		python3-pip \
		&& \
	# Change default python version
	ln -sf python${PYTHON_VERSION} /usr/bin/python && \
	# Clean up
	apt-get clean && \
	rm -rf /var/lib/apt/lists/*


# --
# Base image

FROM python_${PYTHON_BASE} AS app_base

WORKDIR /app

# Install app requirements
COPY --link ./requirements_versions.txt .
RUN pip install --no-cache-dir -r requirements_versions.txt && \
	# Clean up
	pip cache purge && \
	rm -rf /root/.cache/pip

# Install additional runtime requirements
# The shell subcommand converts string '12.1.1' to '121' to format the PyTorch index URL
RUN if [ "${PYTHON_BASE}" = 'cuda' ]; then \
		pip install --no-cache-dir \
			--index-url "https://download.pytorch.org/whl/cu$(echo "${CUDA_VERSION}" | cut -d '.' -f 1,2 | tr -d '.')" \
			torch==2.1.0 \
			torchvision==0.16.0 \
		; \
	else \
		pip install --no-cache-dir \
			torch==2.1.0 \
			torchvision==0.16.0 \
		; \
	fi && \
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
# Dev image

FROM app_base AS app_dev

# Mount source code as volume
VOLUME /app

# Expose port
EXPOSE ${PORT}

CMD [ "/bin/sh", "-c", "python entry_with_update.py --listen \"0.0.0.0\" --port \"${PORT}\"" ]
