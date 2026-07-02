ARG RUBY_VERSION=3.3.11

FROM ruby:${RUBY_VERSION}-slim AS base

WORKDIR /app

ENV RAILS_LOG_TO_STDOUT=true

FROM base AS development

RUN apt-get update -qq \
    && apt-get install -y --no-install-recommends \
        build-essential \
        libyaml-dev \
        pkg-config \
        libpq-dev \
        nodejs \
        git \
        curl \
    && rm -rf /var/lib/apt/lists/*

COPY Gemfile Gemfile.lock ./
RUN gem install bundler && bundle install --jobs=4 --retry=3

COPY . .

EXPOSE 3000

CMD ["bash", "-lc", "bin/rails db:migrate && bin/rails server -b 0.0.0.0 -p 3000"]

FROM base AS build

RUN apt-get update -qq \
    && apt-get install -y --no-install-recommends \
        build-essential \
        libyaml-dev \
        pkg-config \
        libpq-dev \
        git \
    && rm -rf /var/lib/apt/lists/*

COPY Gemfile Gemfile.lock ./
RUN gem install bundler && bundle install --jobs=4 --retry=3

COPY . .

FROM base AS production

RUN apt-get update -qq \
    && apt-get install -y --no-install-recommends \
        libpq5 \
        libyaml-0-2 \
        curl \
    && rm -rf /var/lib/apt/lists/*

COPY --from=build /usr/local/bundle /usr/local/bundle
COPY --from=build /app /app

EXPOSE 3000

CMD ["bin/rails", "server", "-b", "0.0.0.0", "-p", "3000"]