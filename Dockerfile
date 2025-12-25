FROM ruby:4.0.0-alpine as base
WORKDIR /app
ENV BUNDLE_WITHOUT=development BUNDLE_PATH=/app/vendor/bundle BUNDLE_BIN=/app/vendor/bundle/bin BUNDLE_DEPLOYMENT=1

FROM base AS build
COPY . .
RUN apk add --no-cache git build-base ruby-dev && \
    bundle install && \
    rm -rf ~/.bundle/ "${BUNDLE_PATH}"/ruby/*/cache "${BUNDLE_PATH}"/ruby/*/bundler/gems/*/.git 

FROM base
COPY --from=build /app /app
RUN addgroup app && \
    adduser app --home /app --shell /bin/bash --ingroup app --disabled-password && \
    chown -R app:app /app
USER app
CMD ["bundle", "exec", "ruby", "main.rb"]
