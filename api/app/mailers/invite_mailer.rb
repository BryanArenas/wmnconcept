# Sends a provisioned account its invitation: a link to set a password and, in
# doing so, confirm control of the email address. Until the invitee follows it,
# the account stays inactive and cannot sign in (see Invitable). Postmark in
# production; the :test adapter collects it in dev/test.
class InviteMailer < ApplicationMailer
  # params: principal (User or AgencyUser), accept_url, inviter_name
  def invite
    @principal    = params[:principal]
    @accept_url   = params[:accept_url]
    @inviter_name = params[:inviter_name]
    @org_name     = @principal.organization.name

    mail(
      to: @principal.email,
      subject: "You're invited to #{@org_name}"
    )
  end
end
