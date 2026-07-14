module AvailabilityBlockSerializer
  module_function

  def call(block)
    {
      id: block.id,
      starts_at: block.starts_at.iso8601,
      ends_at: block.ends_at.iso8601,
      all_day: block.all_day,
      reason: block.reason,
      created_at: block.created_at.iso8601
    }
  end
end
