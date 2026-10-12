import Config

# RingLogger is a LoggerBackends backend. Adding it here, while the release
# boots and before the applications start, keeps their startup logs without
# the deprecated `config :logger, backends: [...]` key.
if config_target() != :host do
  Application.ensure_all_started(:logger_backends)
  LoggerBackends.add(RingLogger)
end
