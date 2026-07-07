class CreateWebhookEvents < ActiveRecord::Migration[8.1]
  def change
    # bigint PK — internal idempotency ledger, never URL-reachable (spec §0, §3).
    create_table :webhook_events do |t|
      t.string :provider, null: false
      t.string :external_id, null: false
      t.jsonb :payload, null: false, default: {}
      # Set once the event's side effects have been applied. A second delivery of
      # the same (provider, external_id) is a no-op (spec §9 idempotency).
      t.datetime :processed_at

      t.timestamps
    end

    # THE idempotency key (spec §3, §9): a provider can deliver an event more than
    # once; the unique index makes the second insert fail so we never double-apply.
    add_index :webhook_events, [:provider, :external_id], unique: true,
              name: "index_webhook_events_on_provider_and_external_id"
  end
end
