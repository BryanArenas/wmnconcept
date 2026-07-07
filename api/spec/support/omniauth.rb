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

  def sign_in_via_omniauth(user, provider: :google_oauth2, uid: "provider-uid-123")
    mock_omniauth(provider: provider, uid: uid, email: user.email, name: user.name)
    get "/auth/#{provider}/callback"
  end
end

RSpec.configure do |config|
  config.include OmniAuthSpecHelper, type: :request

  config.after do
    OmniAuth.config.mock_auth.clear
  end
end
