Rails.application.configure do
  config.lograge.enabled = true
  config.lograge.formatter = Lograge::Formatters::Json.new

  config.lograge.custom_options = lambda do |event|
    extras = {}
    extras[:request_id] = event.payload[:request_id]
    extras[:organization_id] = event.payload[:organization_id] if event.payload[:organization_id]
    extras[:user_id] = event.payload[:user_id] if event.payload[:user_id]
    extras
  end
end
