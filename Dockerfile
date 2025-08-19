FROM ruby:3.3.9-slim

# Install system dependencies
RUN apt-get update -qq \
    && apt-get install -y --no-install-recommends \
        build-essential \
        libsqlite3-dev \
        libyaml-dev \
        pkg-config \
        sqlite3 \
        nodejs \
        git \
        curl \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

# Install bundler and cache Gemfile gems
COPY Gemfile Gemfile.lock ./
RUN gem install bundler && bundle install --jobs=4 --retry=3

# Copy the rest of the app
COPY . .

ENV RAILS_LOG_TO_STDOUT=true

EXPOSE 3000

# Run migrations then start Puma (Rails default server)
CMD ["bash", "-lc", "bin/rails db:migrate && bin/rails server -b 0.0.0.0 -p 3000"]
