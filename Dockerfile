# =============================================================================
# Stage 1: Build
# =============================================================================
ARG ELIXIR_VERSION=1.18.3
ARG OTP_VERSION=27.3
ARG DEBIAN_VERSION=bookworm-20250113-slim

ARG BUILDER_IMAGE="hexpm/elixir:${ELIXIR_VERSION}-erlang-${OTP_VERSION}-debian-${DEBIAN_VERSION}"
ARG RUNNER_IMAGE="debian:${DEBIAN_VERSION}"

FROM ${BUILDER_IMAGE} AS builder

RUN apt-get update -y && apt-get install -y build-essential git \
    && apt-get clean && rm -f /var/lib/apt/lists/*_*

WORKDIR /app

RUN mix local.hex --force && mix local.rebar --force

ENV MIX_ENV="prod"

# Install dependencies
COPY mix.exs mix.lock ./
RUN mix deps.get --only $MIX_ENV
RUN mkdir config

# Copy compile-time config
COPY config/config.exs config/${MIX_ENV}.exs config/
RUN mix deps.compile

# Copy application code
COPY priv priv
COPY lib lib
COPY assets assets

# Compile assets
RUN mix assets.deploy

# Compile the release
RUN mix compile

# Build release
COPY config/runtime.exs config/
COPY rel rel
RUN mix release

# =============================================================================
# Stage 2: Runtime
# =============================================================================
FROM ${RUNNER_IMAGE}

RUN apt-get update -y && \
    apt-get install -y libstdc++6 openssl libncurses5 locales ca-certificates ffmpeg \
    && apt-get clean && rm -f /var/lib/apt/lists/*_*

# Set locale
RUN sed -i '/en_US.UTF-8/s/^# //g' /etc/locale.gen && locale-gen
ENV LANG en_US.UTF-8
ENV LANGUAGE en_US:en
ENV LC_ALL en_US.UTF-8

WORKDIR /app
RUN chown nobody /app
ENV MIX_ENV="prod"

# Copy the release from build stage
COPY --from=builder --chown=nobody:root /app/_build/${MIX_ENV}/rel/astra_auto_ex ./

USER nobody

# If using an environment that doesn't automatically reap zombie processes,
# set tini as the entrypoint.
# ENTRYPOINT ["bin/astra_auto_ex"]

CMD ["sh", "-c", "/app/bin/migrate && /app/bin/server"]
