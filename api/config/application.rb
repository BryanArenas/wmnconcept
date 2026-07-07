require_relative "boot"

require "rails"
# Pick the frameworks you want:
require "active_model/railtie"
require "active_job/railtie"
require "active_record/railtie"
require "active_storage/engine"
require "action_controller/railtie"
require "action_mailer/railtie"
require "action_mailbox/engine"
require "action_text/engine"
require "action_view/railtie"
require "action_cable/engine"
# require "rails/test_unit/railtie"

# Require the gems listed in Gemfile, including any gems
# you've limited to :test, :development, or :production.
Bundler.require(*Rails.groups)

module Api
  class Application < Rails::Application
    # Initialize configuration defaults for originally generated Rails version.
    config.load_defaults 8.1

    # Please, add to the `ignore` list any other `lib` subdirectories that do
    # not contain `.rb` files, or that should not be reloaded or eager loaded.
    # Common ones are `templates`, `generators`, or `middleware`, for example.
    config.autoload_lib(ignore: %w[assets tasks])

    # Configuration for the application, engines, and railties goes here.
    #
    # These settings can be overridden in specific environments using the files
    # in config/environments, which are processed later.
    #
    # config.time_zone = "Central Time (US & Canada)"
    # config.eager_load_paths << Rails.root.join("extras")

    # Only loads a smaller set of middleware suitable for API only apps.
    # Middleware like session, flash, cookies can be added back manually.
    # Skip views, helpers and assets when generating a new resource.
    config.api_only = true

    # API-only mode drops cookies/session. We run a first-party HTTPOnly,
    # SameSite=Lax cookie session shared with the Next app across a common
    # parent domain (spec §10). No JWT at MVP. OmniAuth (added later in the
    # stack) also relies on this session for its request phase.
    config.middleware.use ActionDispatch::Cookies
    config.session_store :cookie_store,
                         key: "_wmn_session",
                         same_site: :lax,
                         secure: Rails.env.production?,
                         httponly: true,
                         domain: ENV["SESSION_COOKIE_DOMAIN"].presence
    config.middleware.use config.session_store, config.session_options

    # Time zone: WMN operates on the Florida gulf coast.
    config.time_zone = "America/New_York"

    # Generators: RSpec + FactoryBot; fixtures are forbidden (CLAUDE.md).
    config.generators do |g|
      g.test_framework :rspec, fixture: false
      g.fixture_replacement :factory_bot, dir: "spec/factories"
    end
  end
end
