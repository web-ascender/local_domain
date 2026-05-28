module LocalDomain
  class Config
    DEFAULTS = {
      tld:            "localhost",
      admin_url:      "http://127.0.0.1:2019",
      port_range:     (3000..3999),
      caddy_listen:   ":443",
      bind_host:      "127.0.0.1",
      state_dir:      File.expand_path("~/.local_domain"),
    }.freeze

    attr_accessor :tld, :admin_url, :port_range, :caddy_listen, :bind_host, :state_dir

    def initialize
      DEFAULTS.each { |k, v| public_send("#{k}=", v) }
      load_env_overrides
    end

    def hostname_for(subdomain)
      "#{subdomain}.#{tld}"
    end

    def route_id_for(subdomain)
      "local_domain_#{subdomain}"
    end

    def caddy_config_path
      File.join(state_dir, "caddy.json")
    end

    private

    def load_env_overrides
      self.admin_url     = ENV["LOCAL_DOMAIN_ADMIN_URL"]    if ENV["LOCAL_DOMAIN_ADMIN_URL"]
      self.tld           = ENV["LOCAL_DOMAIN_TLD"]          if ENV["LOCAL_DOMAIN_TLD"]
      self.caddy_listen  = ENV["LOCAL_DOMAIN_LISTEN"]       if ENV["LOCAL_DOMAIN_LISTEN"]
      self.bind_host     = ENV["LOCAL_DOMAIN_BIND"]         if ENV["LOCAL_DOMAIN_BIND"]
    end
  end
end
