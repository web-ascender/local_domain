require "local_domain/version"
require "local_domain/config"
require "local_domain/caddy_client"
require "local_domain/port_picker"

module LocalDomain
  class Error < StandardError; end
  class CaddyUnavailableError < Error; end
  class NoFreePortError < Error; end

  def self.config
    @config ||= Config.new
  end

  def self.subdomain_for(path = Dir.pwd)
    File.basename(path).downcase.gsub(/[^a-z0-9-]/, "-")
  end
end

# Prepend the Rails::Server patch at gem-load time. ServerCommand requires
# rails/commands/server/server_command (which defines Rails::Server) BEFORE it
# `require APP_PATH`s the app, which is what triggers Bundler.require and
# loads this gem. So by the time we get here, Rails::Server exists and has
# already been instantiated — but `start` hasn't been called yet.
#
# A Railtie initializer is too late: initializers fire from inside
# `Rails::Server#start` (when config/environment.rb runs), so prepending then
# can't intercept the currently-executing call.
if defined?(::Rails::Server)
  require "local_domain/rails_server_patch"
  ::Rails::Server.prepend(LocalDomain::RailsServerPatch) unless ::Rails::Server.include?(LocalDomain::RailsServerPatch)
end

# Railtie still handles config.hosts (runs at the right moment for that).
require "local_domain/railtie" if defined?(::Rails::Railtie)
