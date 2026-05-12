FROM elixir:1.19-otp-28-alpine AS builder

RUN apk add --no-cache build-base git

WORKDIR /app

RUN mix local.hex --force && mix local.rebar --force

ENV MIX_ENV=prod

COPY mix.exs mix.lock ./
RUN mix deps.get

COPY config/ config/
RUN mix deps.compile

# Download tailwind/esbuild binaries into the prod build tree
RUN mix tailwind.install --if-missing && \
    mix esbuild.install --if-missing

COPY priv/ priv/
COPY assets/ assets/
RUN mix assets.deploy

COPY lib/ lib/
RUN mix compile
RUN mix release


FROM alpine:3.21 AS runner

RUN apk add --no-cache libstdc++ openssl ncurses-libs

WORKDIR /app

RUN addgroup -g 1000 -S app && adduser -u 1000 -S app -G app

COPY --from=builder --chown=app:app /app/_build/prod/rel/metrics_noise ./

USER app

ENV PHX_SERVER=true
EXPOSE 4000

CMD ["bin/metrics_noise", "start"]
