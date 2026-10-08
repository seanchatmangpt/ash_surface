import Config

config :ash, :default_string_length_count, :codepoints

import_config "#{config_env()}.exs"
