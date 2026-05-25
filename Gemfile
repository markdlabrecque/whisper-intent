source "https://rubygems.org"

# Fastlane and its dependencies. Pinned so `bundle exec fastlane ...`
# resolves to the same version on every machine and in CI. Bump deliberately.
gem "fastlane", "~> 2.220"

# Plugins consumed by fastlane/Fastfile. Add new entries here when adopting
# a new plugin; remove when no longer used.
plugins_path = File.join(File.dirname(__FILE__), "fastlane", "Pluginfile")
eval_gemfile(plugins_path) if File.exist?(plugins_path)
