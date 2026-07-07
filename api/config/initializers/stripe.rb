# Stripe is loaded on demand (require: false in the Gemfile) so it adds no boot
# cost when billing is not configured. The API key is set here only when present;
# StripeGateway.configured? gates every real call, and the dev/test stub path
# runs the full billing + webhook flow without live credentials.
if ENV["STRIPE_SECRET_KEY"].present?
  require "stripe"
  Stripe.api_key = ENV["STRIPE_SECRET_KEY"]
  Stripe.api_version = "2024-06-20" if Stripe.respond_to?(:api_version=)
end
