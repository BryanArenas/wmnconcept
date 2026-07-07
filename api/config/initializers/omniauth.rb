# OmniAuth: Google + GitHub for both staff and agency logins (spec §12 M1).
# The browser hits the request phase (POST /auth/:provider), the provider
# redirects back to GET /auth/:provider/callback, and SessionsController#create
# consumes request.env["omniauth.auth"]. No passwords at MVP.

# CSRF-protect the request phase: only POST may initiate a login.
OmniAuth.config.allowed_request_methods = %i[post]
OmniAuth.config.logger = Rails.logger

# Send provider/config errors to a JSON-friendly failure route rather than
# raising in production.
OmniAuth.config.on_failure = proc do |env|
  Api::V1::SessionsController.action(:failure).call(env)
end

Rails.application.config.middleware.use OmniAuth::Builder do
  provider :google_oauth2,
           ENV["GOOGLE_OAUTH_CLIENT_ID"],
           ENV["GOOGLE_OAUTH_CLIENT_SECRET"],
           scope: "email,profile",
           prompt: "select_account"

  provider :github,
           ENV["GITHUB_OAUTH_CLIENT_ID"],
           ENV["GITHUB_OAUTH_CLIENT_SECRET"],
           scope: "user:email"
end

# Local-only auth shim for e2e/manual testing without live OAuth credentials.
# Strictly opt-in (OMNIAUTH_TEST_MODE=1) and refused outside development so it
# can never become a production auth bypass. Hitting the callback signs you in
# as OMNIAUTH_TEST_EMAIL via the normal from_omniauth path (role still comes
# from that user record, not a switcher).
if ENV["OMNIAUTH_TEST_MODE"] == "1" && Rails.env.development?
  OmniAuth.config.test_mode = true
  OmniAuth.config.mock_auth[:google_oauth2] = OmniAuth::AuthHash.new(
    provider: "google_oauth2",
    uid: "dev-#{ENV.fetch('OMNIAUTH_TEST_EMAIL', 'coordinator@windmitigation.network')}",
    info: {
      email: ENV.fetch("OMNIAUTH_TEST_EMAIL", "coordinator@windmitigation.network"),
      name: "Dev User"
    }
  )
end
