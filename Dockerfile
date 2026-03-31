FROM ruby:4.0.2-alpine AS base
WORKDIR /app
ENV BUNDLE_WITHOUT=development BUNDLE_PATH=/app/vendor/bundle BUNDLE_BIN=/app/vendor/bundle/bin BUNDLE_DEPLOYMENT=1

FROM base AS build
COPY . .
RUN apk add --no-cache git build-base ruby-dev linux-headers && \
    bundle install && \
    rm -rf ~/.bundle/ "${BUNDLE_PATH}"/ruby/*/cache "${BUNDLE_PATH}"/ruby/*/bundler/gems/*/.git

FROM base
COPY --from=build /app /app
RUN addgroup app && \
    adduser app --home /app --shell /bin/bash --ingroup app --disabled-password && \
    mkdir -p /app/db && \
    chown -R app:app /app
USER app
VOLUME /app/db
ENV DB_PATH=/app/db/messages.db
CMD ["bundle", "exec", "ruby", "main.rb"]