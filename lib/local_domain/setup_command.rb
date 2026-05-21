require "local_domain"
require "fileutils"
require "json"

module LocalDomain
  class SetupCommand
    PLIST_LABEL = "com.local-domain.caddy".freeze

    def call
      check_caddy_installed!
      ensure_state_dir
      write_caddy_config
      write_launchd_plist

      if caddy_running?
        load_config_into_running_caddy
        puts "✓ Caddy is running. Loaded local_domain config via admin API."
      else
        puts "Caddy is installed but not running."
      end

      print_next_steps
    end

    private

    def check_caddy_installed!
      return if system("command -v caddy > /dev/null 2>&1")

      warn "caddy was not found on PATH."
      warn "Install it first:  brew install caddy"
      exit 1
    end

    def ensure_state_dir
      FileUtils.mkdir_p(LocalDomain.config.state_dir)
    end

    def write_caddy_config
      config = {
        "admin" => { "listen" => admin_listen },
        "apps"  => {
          "http" => {
            "servers" => {
              CaddyClient::SERVER_NAME => {
                "listen" => [LocalDomain.config.caddy_listen],
                "routes" => [],
              },
            },
          },
        },
      }
      File.write(LocalDomain.config.caddy_config_path, JSON.pretty_generate(config))
      puts "✓ wrote #{LocalDomain.config.caddy_config_path}"
    end

    def write_launchd_plist
      File.write(plist_path, plist_contents)
      puts "✓ wrote #{plist_path}"
    end

    def caddy_running?
      CaddyClient.new.healthy?
    end

    def load_config_into_running_caddy
      CaddyClient.new.load_base_config
    rescue CaddyUnavailableError => e
      warn "Could not push config to running Caddy: #{e.message}"
    end

    def admin_listen
      uri = URI(LocalDomain.config.admin_url)
      "#{uri.host}:#{uri.port}"
    end

    def plist_path
      File.join(LocalDomain.config.state_dir, "#{PLIST_LABEL}.plist")
    end

    def caddy_bin
      `command -v caddy`.strip
    end

    def plist_contents
      config_path = LocalDomain.config.caddy_config_path
      log_path    = File.join(LocalDomain.config.state_dir, "caddy.log")
      <<~PLIST
        <?xml version="1.0" encoding="UTF-8"?>
        <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
        <plist version="1.0">
        <dict>
          <key>Label</key>
          <string>#{PLIST_LABEL}</string>
          <key>ProgramArguments</key>
          <array>
            <string>#{caddy_bin}</string>
            <string>run</string>
            <string>--config</string>
            <string>#{config_path}</string>
          </array>
          <key>RunAtLoad</key>
          <true/>
          <key>KeepAlive</key>
          <true/>
          <key>StandardOutPath</key>
          <string>#{log_path}</string>
          <key>StandardErrorPath</key>
          <string>#{log_path}</string>
        </dict>
        </plist>
      PLIST
    end

    def print_next_steps
      puts
      puts "Next steps (one-time):"
      puts
      puts "  1) Install Caddy's local root CA so HTTPS certs are trusted:"
      puts "       sudo caddy trust"
      puts
      puts "  2) Install Caddy as a system service so it starts on boot and can"
      puts "     bind to port #{LocalDomain.config.caddy_listen}:"
      puts "       sudo cp #{plist_path} /Library/LaunchDaemons/"
      puts "       sudo launchctl bootstrap system /Library/LaunchDaemons/#{PLIST_LABEL}.plist"
      puts
      puts "  To just start it for this shell session instead:"
      puts "       sudo caddy run --config #{LocalDomain.config.caddy_config_path}"
      puts
      puts "Once Caddy is running, change your project's Procfile.dev:"
      puts "       web: bundle exec local_domain serve"
      puts "and visit  https://<your-folder>.#{LocalDomain.config.tld}"
    end
  end
end
