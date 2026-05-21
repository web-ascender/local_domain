module LocalDomain
  # ANSI-styled multi-line banner so the subdomain URL stands out in the
  # middle of foreman/overmind output. Honors NO_COLOR for plain output.
  module Banner
    RESET   = "\e[0m"
    BOLD    = "\e[1m"
    DIM     = "\e[2m"
    CYAN    = "\e[96m"
    MAGENTA = "\e[95m"
    GREEN   = "\e[92m"
    GREY    = "\e[90m"

    module_function

    def started(host:, port:, bind:)
      url      = "https://#{host}"
      upstream = "#{bind}:#{port}"
      width    = [url.length, upstream.length + 14, 44].max + 4
      bar      = "━" * width

      [
        "",
        color(CYAN,  bar),
        "  #{color(BOLD + MAGENTA, "LOCAL_DOMAIN")}  #{color(GREY, "ready")}",
        "  #{color(BOLD + CYAN, url)}",
        "  #{color(GREY, "→ proxying to #{color(GREEN, upstream)}")}",
        color(CYAN,  bar),
        "",
      ].join("\n")
    end

    def stopped(host:)
      color(GREY, "local_domain: unregistered https://#{host}")
    end

    def warning(message)
      "#{color(BOLD + MAGENTA, "LOCAL_DOMAIN")} #{color(GREY, message)}"
    end

    # Sets the terminal window + tab title via OSC 0. Writes directly to
    # /dev/tty so it works even when stdout is piped through foreman/overmind.
    def set_terminal_title(title)
      return if ENV["LOCAL_DOMAIN_NO_TITLE"] == "1"

      File.open("/dev/tty", "a") { |tty| tty.write("\e]0;#{title}\a") }
    rescue StandardError
      # No controlling tty (CI, daemon, etc.) — skip silently.
    end

    def color(code, text)
      return text if no_color?
      "#{code}#{text}#{RESET}"
    end

    def no_color?
      ENV["NO_COLOR"] && !ENV["NO_COLOR"].empty?
    end
  end
end
