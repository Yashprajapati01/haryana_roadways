FROM dart:stable AS build
WORKDIR /app
COPY bin bin
COPY live_rule.dart live_rule.dart
RUN dart compile exe bin/live.dart -o /live

FROM debian:bookworm-slim
COPY --from=build /live /live
ENV PORT=8080
EXPOSE 8080
CMD ["/live"]
