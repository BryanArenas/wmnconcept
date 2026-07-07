# OmniAuth test mode: no live provider round-trip. Specs stub the auth hash and
# hit the callback route directly, exercising the real SessionsController path.
OmniAuth.config.test_mode = true

module OmniAuthSpecHelper
  # Build and register a provider auth hash so a request to
  # GET /auth/:provider/callback resolves to `email`.
  def mock_omniauth(provider: :google_oauth2, uid: "provider-uid-123", email:, name: "Test User")
    auth = OmniAuth::AuthHash.new(
      provider: provider.to_s,
      uid: uid,
      info: { email: email, name: name }
    )
    OmniAuth.config.mock_auth[provider.to_sym] = auth
    auth
  end

  # Sign in any principal (staff User or AgencyUser). The uid derives from the
  # email so signing in different principals within one example never collides
  # on a shared uid. The request host is set to the principal's org subdomain so
  # the callback resolves the right tenant regardless of creation order.
  def sign_in_via_omniauth(principal, provider: :google_oauth2, uid: nil)
    uid ||= "uid-#{principal.email}"
    mock_omniauth(provider: provider, uid: uid, email: principal.email, name: principal.name)
    host = "#{principal.organization.subdomain}.example.com"
    get "/auth/#{provider}/callback", headers: { "HOST" => host }
  end
end

RSpec.configure do |config|
  config.include OmniAuthSpecHelper, type: :request

  config.after do
    OmniAuth.config.mock_auth.clear
  end
end
