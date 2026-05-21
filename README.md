# local_domain

Run multiple Rails apps simultaneously on pretty `.localhost` subdomains.

```
~/code/my-app             $ bin/dev   →   https://my-app.localhost
~/code/another-app        $ bin/dev   →   https://another-app.localhost
~/code/wiki               $ bin/dev   →   https://wiki.localhost
~/code/blog               $ bin/dev   →   https://blog.localhost
```

All four servers run at the same time. Each Rails app picks a free port automatically.
You don't have to type ports in the URL. You don't have to remember which app is on which port.

## How it works

[Caddy](https://caddyserver.com) is the reverse proxy. It listens on `:443`,
holds a local CA, and auto-issues HTTPS certificates for `*.localhost`.

`local_domain` is a thin Ruby client. A Railtie prepends `Rails::Server#start`,
so when `bin/dev` (or `bin/rails server`) boots:

1. Reads the current folder name (e.g. `my-app`).
2. Picks a free TCP port in `3001..3999`.
3. POSTs a route to Caddy's admin API: `host = my-app.localhost`,
   `reverse_proxy 127.0.0.1:<port>`.
4. Mutates the server's bind options so Puma listens on that port.
5. On shutdown, removes the route via Caddy's admin API.

There is no daemon to manage other than Caddy itself.

## One-time machine setup

```sh
brew install caddy
gem install local_domain        # or add to a Gemfile group below
local_domain setup
```

The `setup` command writes a minimal Caddy config and a launchd plist into
`~/.local_domain/`, then prints the two `sudo` commands you need to run once:

```sh
sudo caddy trust                              # trust the local root CA
sudo cp ~/.local_domain/com.local-domain.caddy.plist /Library/LaunchDaemons/
sudo launchctl bootstrap system /Library/LaunchDaemons/com.local-domain.caddy.plist
```

After that, Caddy starts at boot, listens on `:443`, and waits for `local_domain`
to register subdomains.

If you already have Caddy running with its own config, `local_domain` will *add*
its routes to whatever HTTPS server is already there (auto-detected) rather than
clobbering your existing setup.

## Per-project setup

Add the gem to your Rails app's Gemfile. **That's it.** No Procfile.dev edits,
no `config/puma.rb` changes:

```ruby
group :development do
  gem "local_domain"
end
```

Run `bin/dev` (or `bin/rails server`) and visit `https://<your-folder-name>.localhost`.

The Railtie does two things:
- Prepends `Rails::Server#start` to override the port and register/unregister
  the Caddy route around server lifetime.
- Appends `<folder>.localhost` to `config.hosts` so Rails' DNS rebinding
  protection doesn't 403 the proxied request.

If you ever need to bypass the hook (run on the original port, no Caddy):

```sh
LOCAL_DOMAIN_DISABLE=1 bin/dev
```

### Bypassing Rails::Server

A few setups invoke Puma directly and never go through `Rails::Server`
(e.g. `bundle exec puma -C config/puma.rb`). For those, use the explicit
wrapper in `Procfile.dev`:

```diff
- web: bundle exec puma -C config/puma.rb
+ web: bundle exec local_domain serve
```

`local_domain serve` does the same port/Caddy setup, then `exec`s `rails server`.

## CLI

```
local_domain setup           Write Caddy config + launchd plist and print next steps.
local_domain serve [args]    Pick a port, register with Caddy, then exec `rails server`.
local_domain status          Show currently registered subdomains and upstream ports.
local_domain stop <subd>     Unregister a subdomain from Caddy.
local_domain version
local_domain help
```

## Configuration

Environment variables:

| Var | Default | Meaning |
| --- | --- | --- |
| `LOCAL_DOMAIN_ADMIN_URL` | `http://127.0.0.1:2019` | Caddy admin API endpoint |
| `LOCAL_DOMAIN_TLD`       | `localhost`             | TLD used for `<folder>.<tld>` |
| `LOCAL_DOMAIN_LISTEN`    | `:443`                  | Port Caddy listens on (HTTPS) |
| `LOCAL_DOMAIN_BIND`      | `127.0.0.1`             | Host Rails binds to |

## Troubleshooting

**TLS handshake error the very first time you hit a new subdomain.** Caddy
issues a cert on demand; the first request occasionally beats the cert
provisioning. Retry once.

**"Caddy admin API not reachable".** Caddy isn't running or it's running
without `--config` pointing at one that enables the admin endpoint. Re-run
`local_domain setup` to see what's expected, then start Caddy via the
launchd plist `setup` generated.

**Rails 403 "Blocked host".** The Railtie didn't load. Confirm `local_domain`
is in your `:development` group and that `Rails.env.development?` is true.

## License

MIT
