# Dockerfile
FROM ruby:2.7

WORKDIR /usr/src/app

COPY Gemfile Gemfile.lock ./
RUN bundle install

COPY app.rb ./

CMD ["bundle", "exec", "ruby", "app.rb"]
