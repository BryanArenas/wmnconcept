# Session-based auth over the shared HTTPOnly cookie (spec §10). The signed-in
# user id lives in the session; role is derived from that record, never from a
# client-supplied value or switcher (spec §13). Access the session via
# `request.session` so the concern works cleanly in API-only controllers.
module Authentication
  extend ActiveSupport::Concern

  included do
    before_action :set_current_request_details
  end

  def current_user
    return @current_user if defined?(@current_user)

    @current_user = if (id = request.session[:user_id])
      User.active.find_by(id: id)
    end
  end

  def current_organization
    current_user&.organization || resolve_organization
  end

  def signed_in?
    current_user.present?
  end

  # Guard for protected actions. Renders the 401 envelope and halts.
  def authenticate_user!
    return if signed_in?

    render_error(code: "unauthorized", message: "Authentication required", status: :unauthorized)
  end

  def sign_in(user)
    request.reset_session # rotate session id on privilege change (fixation defense)
    request.session[:user_id] = user.id
    @current_user = user
    Current.user = user
  end

  def sign_out
    @current_user = nil
    Current.user = nil
    request.reset_session
  end

  private

  def set_current_request_details
    Current.request_id = request.request_id
    Current.user_agent = request.user_agent
    Current.ip_address = request.remote_ip
    Current.user = current_user
  end

  # Single tenant at launch: resolve the org by request subdomain, else fall
  # back to the launch (oldest) organization. Ordered by created_at because a
  # UUID PK gives no meaningful `.first`. Kept multi-tenant-ready (spec §13)
  # without building white-label machinery.
  def resolve_organization
    @resolve_organization ||= begin
      subdomain = request.subdomains.first
      Organization.find_by(subdomain: subdomain) if subdomain.present?
    end || Organization.order(:created_at).first
  end
end
