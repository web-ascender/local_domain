require "local_domain"
require "local_domain/banner"

module LocalDomain
  # Shared logic used by both the Railtie (transparent `rails server` hook)
  # and the explicit `local_domain serve` CLI command. Picks a free port,
  # registers the route with Caddy, and unregisters on exit.
  class ServerIntegration
    class << self
      def disabled?
        ENV["LOCAL_DOMAIN_DISABLE"] == "1"
      end

      def begin!
        return state if state
        return nil if disabled?

        subdomain = LocalDomain.subdomain_for
        host      = LocalDomain.config.hostname_for(subdomain)
        caddy     = CaddyClient.new

        unless caddy.healthy?
          warn Banner.warning("Caddy admin API not reachable at #{LocalDomain.config.admin_url}.")
          warn Banner.warning("Run `local_domain setup` once. Skipping subdomain wiring.")
          return nil
        end

        port = PortPicker.pick
        caddy.register(subdomain: subdomain, host: host, upstream_port: port)
        $stdout.puts Banner.started(host: host, port: port, bind: LocalDomain.config.bind_host)
        $stdout.flush
        Banner.set_terminal_title(host)

        @state = { subdomain: subdomain, host: host, port: port, caddy: caddy }
        install_at_exit
        @state
      rescue CaddyUnavailableError => e
        warn "local_domain: #{e.message}"
        nil
      end

      def finish!
        s = state
        return unless s
        s[:caddy].unregister(subdomain: s[:subdomain])
        $stdout.puts Banner.stopped(host: s[:host])
        $stdout.flush
      rescue StandardError => e
        warn Banner.warning("cleanup failed: #{e.message}")
      ensure
        @state = nil
      end

      def state
        @state
      end

      private

      def install_at_exit
        return if @at_exit_installed
        @at_exit_installed = true
        at_exit { finish! }
      end
    end
  end
end
