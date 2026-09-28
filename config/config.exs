import Config

config :ash, default_string_length_count: :codepoints

# Test runs keep Ash's per-record :debug action logging out of the suite
# output (no test asserts on logs); warnings and errors still surface.
if config_env() == :test do
  config :logger, level: :warning
end
