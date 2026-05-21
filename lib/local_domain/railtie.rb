require "rails/railtie"
require "local_domain/server_integration"

module LocalDomain
  class Railtie < ::Rails::Railtie
    initializer "local_domain.configure_hosts" do |app|
      next unless ::Rails.env.development?
      next if LocalDomain::ServerIntegration.disabled?

      subdomain = LocalDomain.subdomain_for
      host      = LocalDomain.config.hostname_for(subdomain)

      app.config.hosts ||= []
      app.config.hosts << host unless app.config.hosts.include?(host)
    end
  end
end
