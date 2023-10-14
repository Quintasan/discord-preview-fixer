FROM ruby:3.2.2-alpine as base
WORKDIR /app
ENV BUNDLE_WITHOUT=development BUNDLE_PATH=/app/vendor/bundle BUNDLE_BIN=/app/vendor/bundle/bin BUNDLE_DEPLOYMENT=1

FROM base AS build
COPY . .
RUN apk add --no-cache git && \
    bundle install && \
    rm -rf ~/.bundle/ "${BUNDLE_PATH}"/ruby/*/cache "${BUNDLE_PATH}"/ruby/*/bundler/gems/*/.git 

FROM base
COPY --from=build /app /app
RUN useradd app --create-home --shell /bin/bash && chown -R app:app /app
USER app
CMD ["ruby", "main.rb"]
