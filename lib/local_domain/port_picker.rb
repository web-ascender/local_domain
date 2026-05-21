require "socket"

module LocalDomain
  module PortPicker
    module_function

    def pick(range: LocalDomain.config.port_range, host: LocalDomain.config.bind_host)
      range.each do |port|
        return port if available?(host, port)
      end
      raise NoFreePortError, "No free port in #{range}"
    end

    def available?(host, port)
      server = TCPServer.new(host, port)
      true
    rescue Errno::EADDRINUSE, Errno::EACCES
      false
    ensure
      server&.close
    end
  end
end
