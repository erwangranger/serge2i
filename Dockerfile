# ---------------------------------------
# Base image for node
FROM node:19-bullseye-slim as node_base

# ---------------------------------------
# Base image for runtime
FROM python:3.11-slim-bullseye as base

ENV TZ=Etc/UTC
WORKDIR /usr/src/app

# Install Redis
RUN apt-get update \
    && apt-get install -y curl wget gnupg cmake lsb-release build-essential dumb-init \
    && curl -fsSL https://packages.redis.io/gpg | gpg --dearmor -o /usr/share/keyrings/redis-archive-keyring.gpg \
    && echo "deb [signed-by=/usr/share/keyrings/redis-archive-keyring.gpg] https://packages.redis.io/deb $(lsb_release -cs) main" | tee /etc/apt/sources.list.d/redis.list \
    && apt-get update \
    && apt-get install -y redis \
    && apt-get clean \
    && mkdir -p /etc/redis /var/redis \
    && pip install --upgrade pip \
    && echo "appendonly yes" >> /etc/redis/redis.conf \
    && echo "dir /data/db/" >> /etc/redis/redis.conf

# ---------------------------------------
# Build frontend
FROM node_base as frontend_builder

WORKDIR /usr/src/app
COPY ./web/package.json ./web/package-lock.json ./
RUN npm ci

COPY ./web /usr/src/app/web/
WORKDIR /usr/src/app/web/
RUN npm run build

# ---------------------------------------
# Runtime environment
FROM base as release

# Set ENV
ENV NODE_ENV='production'
WORKDIR /usr/src/app

# Copy artifacts
COPY --from=frontend_builder /usr/src/app/web/build /usr/src/app/api/static/
COPY ./api /usr/src/app/api
COPY scripts/deploy.sh /usr/src/app/deploy.sh

RUN pip install --no-cache-dir ./api \
    && chmod 755 /usr/src/app/deploy.sh

RUN pip install --no-cache-dir llama-cpp-python==0.1.70

RUN chmod -R 755 /etc/redis/ /var/lib/redis/
RUN chmod 755 /usr/src/app/

RUN mkdir -p /data/db/ && chmod 777 /data/db
RUN mkdir -p /usr/src/app/weights/ &&  chmod 777 /usr/src/app/weights/



EXPOSE 8080

CMD ["/bin/bash", "-c", "/usr/src/app/deploy.sh"]
