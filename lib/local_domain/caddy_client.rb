require "net/http"
require "json"
require "uri"

module LocalDomain
  class CaddyClient
    DEFAULT_SERVER_NAME = "local_domain".freeze

    def initialize(admin_url: LocalDomain.config.admin_url)
      @admin_url = admin_url
    end

    def healthy?
      get("/config/")
      true
    rescue StandardError
      false
    end

    def load_base_config
      body = JSON.dump(base_config)
      response = post_json("/load", body)
      raise CaddyUnavailableError, "Caddy /load failed: #{response.code} #{response.body}" unless response.is_a?(Net::HTTPSuccess)
    end

    def register(subdomain:, host:, upstream_port:)
      server = ensure_server!
      route_id = LocalDomain.config.route_id_for(subdomain)
      delete_id(route_id)
      route = {
        "@id"      => route_id,
        "match"    => [{ "host" => [host] }],
        "handle"   => [{
          "handler"   => "reverse_proxy",
          "upstreams" => [{ "dial" => "#{LocalDomain.config.bind_host}:#{upstream_port}" }],
        }],
        "terminal" => true,
      }
      response = post_json("/config/apps/http/servers/#{server}/routes/0", JSON.dump(route))
      unless response.is_a?(Net::HTTPSuccess)
        raise CaddyUnavailableError, "Caddy route add failed: #{response.code} #{response.body}"
      end
      route_id
    end

    def unregister(subdomain:)
      delete_id(LocalDomain.config.route_id_for(subdomain))
    end

    def managed_routes
      servers.flat_map do |name, server|
        Array(server["routes"]).select { |r| r["@id"].to_s.start_with?("local_domain_") }.map do |route|
          host     = route.dig("match", 0, "host", 0)
          upstream = extract_upstream(route)
          { server: name, id: route["@id"], host: host, upstream: upstream }
        end
      end
    end

    private

    def extract_upstream(route)
      handles = Array(route["handle"])
      handles.each do |handle|
        case handle["handler"]
        when "reverse_proxy"
          return handle.dig("upstreams", 0, "dial")
        when "subroute"
          Array(handle["routes"]).each do |sub|
            nested = extract_upstream(sub)
            return nested if nested
          end
        end
      end
      nil
    end

    def servers
      config = JSON.parse(get("/config/").body) rescue {}
      config.dig("apps", "http", "servers") || {}
    end

    def ensure_server!
      existing = servers
      existing.each do |name, server|
        listens = Array(server["listen"])
        return name if listens.any? { |l| l.to_s.include?(LocalDomain.config.caddy_listen) }
      end
      # No matching server — create one.
      response = post_json(
        "/config/apps/http/servers/#{DEFAULT_SERVER_NAME}",
        JSON.dump(default_server),
      )
      unless response.is_a?(Net::HTTPSuccess)
        raise CaddyUnavailableError, "Could not create Caddy server: #{response.code} #{response.body}"
      end
      DEFAULT_SERVER_NAME
    end

    def base_config
      {
        "admin" => { "listen" => admin_listen },
        "apps"  => {
          "http" => {
            "servers" => { DEFAULT_SERVER_NAME => default_server },
          },
        },
      }
    end

    def default_server
      { "listen" => [LocalDomain.config.caddy_listen], "routes" => [] }
    end

    def admin_listen
      uri = URI(@admin_url)
      "#{uri.host}:#{uri.port}"
    end

    def get(path)
      response = request(Net::HTTP::Get.new(path))
      raise "GET #{path} -> #{response.code}" unless response.is_a?(Net::HTTPSuccess)
      response
    end

    def post_json(path, body)
      req = Net::HTTP::Post.new(path, "Content-Type" => "application/json")
      req.body = body
      request(req)
    end

    def delete_id(id)
      request(Net::HTTP::Delete.new("/id/#{id}"))
    rescue StandardError
      # Route may not exist; treat as success.
    end

    def request(req)
      uri = URI(@admin_url)
      Net::HTTP.start(uri.host, uri.port) do |http|
        http.request(req)
      end
    rescue Errno::ECONNREFUSED => e
      raise CaddyUnavailableError, "Caddy admin API not reachable at #{@admin_url}: #{e.message}"
    end
  end
end
