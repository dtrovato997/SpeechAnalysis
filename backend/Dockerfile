FROM python:3.9-slim

# Install system dependencies for audio processing
RUN apt-get update && apt-get install -y \
    ffmpeg \
    libsndfile1 \
    gcc \
    g++ \
    curl \
    && rm -rf /var/lib/apt/lists/*

# Set working directory
WORKDIR /code

# Copy requirements and install Python dependencies
COPY ./requirements.txt /code/requirements.txt
RUN pip install --no-cache-dir --upgrade -r /code/requirements.txt

# Create user with proper permissions for HF Spaces
RUN useradd -m -u 1000 user

# Switch to user
USER user

# Set environment variables
ENV HOME=/home/user \
    PATH=/home/user/.local/bin:$PATH

# Set user's working directory
WORKDIR $HOME/app

# Copy application code with proper ownership
COPY --chown=user . $HOME/app

# Create uploads directory in app folder (for temporary files)
RUN mkdir -p $HOME/app/uploads

# Create symbolic link from /data to cache (if /data exists)
# This will be created at runtime when persistent storage is mounted
RUN mkdir -p $HOME/app/cache

# Expose port 7860 (HF Spaces default)
EXPOSE 7860

# Start the FastAPI app with uvicorn
CMD ["uvicorn", "main:app", "--host", "0.0.0.0", "--port", "7860"]