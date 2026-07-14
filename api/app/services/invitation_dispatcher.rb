# Builds a principal's invitation link and sends the invite email. Returns the
# accept URL so the caller can also surface a copyable link in the admin UI —
# which lets provisioning work end-to-end even before a production email adapter
# (Postmark) is configured. The link carries a signed, single-use token (see
# Invitable); `type` tells the frontend which surface to confirm against and is
# re-validated server-side on accept.
class InvitationDispatcher
  def self.call(principal, inviter: nil)
    new(principal, inviter:).call
  end

  def initialize(principal, inviter: nil)
    @principal = principal
    @inviter   = inviter
  end

  def call
    url = accept_url
    @principal.mark_invited!
    InviteMailer.with(
      principal: @principal,
      accept_url: url,
      inviter_name: @inviter&.try(:name)
    ).invite.deliver_later
    url
  end

  def accept_url
    token = @principal.generate_token_for(:invitation)
    query = URI.encode_www_form(token:, type: principal_type)
    "#{frontend_base}/accept-invite?#{query}"
  end

  private

  def principal_type
    @principal.is_a?(AgencyUser) ? "agency" : "staff"
  end

  def frontend_base
    ENV.fetch("FRONTEND_URL", "http://localhost:3000").chomp("/")
  end
end
