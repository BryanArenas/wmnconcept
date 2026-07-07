class ApplicationController < ActionController::API
  # API-only mode omits these; we add them back for the shared-cookie session
  # (spec §10) and CSRF protection on mutations.
  include ActionController::Cookies
  include ActionController::RequestForgeryProtection

  include ErrorEnvelope
  include Authentication
  include CursorPagination
  include Pundit::Authorization

  # Pundit authorizes the current principal (staff User or AgencyUser).
  def pundit_user
    current_principal
  end

  # CSRF is enforced whenever forgery protection is active. The Next client
  # reads the token from the non-HTTPOnly XSRF-TOKEN cookie and echoes it back
  # as the X-CSRF-Token header on every mutation.
  #
  # `config.action_controller.allow_forgery_protection` is wired onto
  # ActionController::Base; since this API controller includes forgery
  # protection manually, that config doesn't reach it. Mirror it here so the
  # env setting still governs (off in tests, on in dev/production).
  self.allow_forgery_protection =
    Rails.application.config.action_controller.fetch(:allow_forgery_protection, !Rails.env.test?)

  protect_from_forgery with: :exception

  after_action :set_csrf_cookie

  private

  def set_csrf_cookie
    cookies["XSRF-TOKEN"] = {
      value: form_authenticity_token,
      same_site: :lax,
      secure: Rails.env.production?,
      domain: ENV["SESSION_COOKIE_DOMAIN"].presence
    }
  end
end
