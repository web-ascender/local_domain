require "local_domain"
require "local_domain/server_integration"

module LocalDomain
  # Explicit `local_domain serve` entry point. Equivalent to `bin/rails server`
  # but does the Caddy/port dance up front and `exec`s the server. Useful when
  # something invokes Puma directly and bypasses Rails::Server (so the Railtie
  # hook never fires).
  class ServeCommand
    def initialize(args)
      @args = args
    end

    def call
      state = LocalDomain::ServerIntegration.begin!
      port  = state ? state[:port] : 3000
      bind  = LocalDomain.config.bind_host

      child_pid = Process.spawn(*rails_command(port, bind))

      %w[INT TERM HUP QUIT].each do |sig|
        Signal.trap(sig) do
          begin
            Process.kill(sig, child_pid)
          rescue Errno::ESRCH
            # already gone
          end
        end
      end

      _, status = Process.waitpid2(child_pid)
      exit(status.exitstatus || 1)
    end

    private

    def rails_command(port, bind)
      base = File.executable?("bin/rails") ? ["bin/rails"] : ["bundle", "exec", "rails"]
      base + ["server", "-p", port.to_s, "-b", bind, *@args]
    end
  end
end
