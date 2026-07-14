# Email-confirmed invitation flow for provisioned principals (staff Users and
# AgencyUsers). A newly provisioned account is created inactive + unconfirmed;
# it cannot sign in until the invitee follows the emailed link and sets a
# password. This is what "authenticate the email before activating" means here:
# no account goes live until someone proves control of the inbox.
#
# The invite token is a signed, self-expiring token (Rails `generates_token_for`)
# derived from `confirmed_at` — so it is single-use: the moment the account is
# confirmed, every previously issued token stops resolving.
module Invitable
  extend ActiveSupport::Concern

  INVITE_EXPIRES_IN = 14.days

  included do
    has_secure_password validations: false

    generates_token_for :invitation, expires_in: INVITE_EXPIRES_IN do
      # Embedding confirmed_at invalidates the token once the account confirms.
      confirmed_at&.to_i
    end

    scope :confirmed,   -> { where.not(confirmed_at: nil) }
    scope :unconfirmed, -> { where(confirmed_at: nil) }
  end

  class_methods do
    # Resolve a principal from an invitation token, or nil if the token is
    # invalid, expired, or already consumed.
    def from_invitation_token(token)
      find_by_token_for(:invitation, token)
    end
  end

  def confirmed?
    confirmed_at.present?
  end

  # Provisioned but has not yet set a password / confirmed their email.
  def pending_invitation?
    confirmed_at.nil?
  end

  # Mark this account as invited (used to timestamp when the link was sent).
  def mark_invited!
    update!(invited_at: Time.current)
  end

  # The invitee sets their password from the emailed link. Confirming both sets
  # the credential and activates the account in a single transaction, so a
  # half-provisioned login can never sign in.
  def confirm_with_password!(password)
    transaction do
      self.password = password
      self.confirmed_at = Time.current
      self.active = true
      save!
    end
  end
end
