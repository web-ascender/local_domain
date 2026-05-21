require "local_domain/server_integration"

module LocalDomain
  module RailsServerPatch
    def start(*args, **kwargs, &block)
      state = LocalDomain::ServerIntegration.begin!
      apply_port_override(state) if state
      super
    ensure
      LocalDomain::ServerIntegration.finish!
    end

    private

    def apply_port_override(state)
      opts = instance_variable_get(:@default_options) || {}
      opts[:Port] = state[:port]
      opts[:Host] = LocalDomain.config.bind_host
      instance_variable_set(:@default_options, opts)

      # Some Rails versions also memoize options on @options
      if instance_variable_defined?(:@options) && instance_variable_get(:@options)
        cached = instance_variable_get(:@options)
        cached[:Port] = state[:port]
        cached[:Host] = LocalDomain.config.bind_host
      end
    end
  end
end
