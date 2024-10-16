ARG py_version=3.11.2

FROM python:$py_version-slim-bullseye as base

# Update and install dependencies
RUN apt-get update \
  && apt-get dist-upgrade -y \
  && apt-get install -y --no-install-recommends \
    build-essential=12.9 \
    ca-certificates=20210119 \
    git=1:2.30.2-1+deb11u2 \
    libpq-dev=13.16-0+deb11u1 \
    make=4.3-4.1 \
    openssh-client=1:8.4p1-5+deb11u3 \
    software-properties-common=0.96.20.2-2.1 \
  && apt-get clean \
  && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

# Set Python encoding and locale
ENV PYTHONIOENCODING=utf-8
ENV LANG=C.UTF-8

# Upgrade pip, setuptools, and wheel
RUN python -m pip install --upgrade "pip==24.2" "setuptools==69.2.0" "wheel==0.43.0" --no-cache-dir

# Install Rust for compiling dbt-core dependencies
RUN curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y \
  && export PATH="$HOME/.cargo/bin:$PATH"

# Install dbt-core and dbt-postgres from PyPI
WORKDIR /usr/app/dbt/
COPY . /usr/app/dbt/

RUN python -m pip install --no-cache-dir "dbt-core @ git+https://github.com/dbt-labs/dbt-core@main#subdirectory=core" \
    && python -m pip install --no-cache-dir dbt-postgres

# Install third-party adapters if provided
ARG dbt_third_party

RUN if [ "$dbt_third_party" ]; then \
        python -m pip install --no-cache-dir "${dbt_third_party}"; \
    else \
        echo "No third party adapter provided"; \
    fi

# Final image
WORKDIR /usr/app/dbt/