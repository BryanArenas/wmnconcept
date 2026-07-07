# Be sure to restart your server when you modify this file.
#
# Cross-origin access for the Next.js frontend. In dev the app runs on a
# different port; in prod it is a sibling subdomain under the shared cookie
# parent domain. credentials: true is required for the session cookie to ride
# along on browser fetches.
#
# FRONTEND_ORIGINS is a comma-separated allow-list
# (e.g. "https://app.windmitigation.network"). Dev defaults to localhost:3000.
Rails.application.config.middleware.insert_before 0, Rack::Cors do
  allow do
    origins(
      ENV.fetch("FRONTEND_ORIGINS", "http://localhost:3000,http://127.0.0.1:3000")
        .split(",").map(&:strip)
    )

    resource "*",
             headers: :any,
             methods: %i[get post put patch delete options head],
             credentials: true,
             expose: %w[X-Request-Id]
  end
end
