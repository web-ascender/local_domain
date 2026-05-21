require "local_domain"

module LocalDomain
  class CLI
    COMMANDS = %w[setup serve status list stop help version].freeze

    def initialize(argv)
      @argv = argv.dup
    end

    def call
      cmd = @argv.shift || "help"
      case cmd
      when "setup"          then require_and_run(SetupCommand)
      when "serve", "start" then require_and_run(ServeCommand, @argv)
      when "status", "list" then status
      when "stop"           then stop(@argv.first)
      when "version", "-v", "--version" then puts VERSION
      when "help", "-h", "--help", nil   then print_help
      else
        warn "Unknown command: #{cmd}"
        print_help
        exit 1
      end
    end

    private

    def require_and_run(klass, *args)
      file = klass.name.split("::").last.gsub(/([A-Z])/) { "_#{$1.downcase}" }.sub(/^_/, "")
      require "local_domain/#{file}"
      klass.new(*args).call
    end

    def status
      caddy = CaddyClient.new
      unless caddy.healthy?
        warn "Caddy not reachable at #{LocalDomain.config.admin_url}. Run `local_domain setup`."
        exit 1
      end
      routes = caddy.managed_routes
      if routes.empty?
        puts "No subdomains registered by local_domain."
        return
      end
      routes.each do |route|
        puts "  https://#{route[:host]}  ->  #{route[:upstream]}"
      end
    end

    def stop(subdomain)
      unless subdomain
        warn "Usage: local_domain stop <subdomain>"
        exit 1
      end
      CaddyClient.new.unregister(subdomain: subdomain)
      puts "✓ removed #{LocalDomain.config.hostname_for(subdomain)}"
    end

    def print_help
      puts <<~HELP
        local_domain v#{VERSION}

          Run multiple Rails apps simultaneously on pretty .#{LocalDomain.config.tld} subdomains.

        Commands:
          local_domain setup           Write Caddy config + launchd plist and print next steps.
          local_domain serve [args]    Pick a port, register with Caddy, then exec `rails server`.
          local_domain status          Show currently registered subdomains and upstream ports.
          local_domain stop <subd>     Unregister a specific subdomain from Caddy.
          local_domain version         Show the gem version.
          local_domain help            This message.

        Typical project setup (one line in Procfile.dev):
          web: bundle exec local_domain serve
      HELP
    end
  end
end
