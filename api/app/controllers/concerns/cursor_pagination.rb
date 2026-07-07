# Opaque keyset (cursor) pagination for every index action (spec §0, §4).
# Offset pagination is forbidden — it drifts and scans. The cursor encodes the
# last row's (order_column, tiebreak id) so the next page is a single indexed
# range scan via a Postgres row-value comparison.
#
# Usage in an index action:
#   records, next_cursor = paginate(scope)
#   render json: { data: records.map { ... }, meta: { next_cursor: next_cursor } }
module CursorPagination
  extend ActiveSupport::Concern

  DEFAULT_LIMIT = 25
  MAX_LIMIT = 100

  def paginate(scope, order_column: :created_at, tiebreak: :id, direction: :desc)
    table = scope.model.quoted_table_name
    order_col = scope.model.connection.quote_column_name(order_column)
    tiebreak_col = scope.model.connection.quote_column_name(tiebreak)

    scope = scope.reorder(order_column => direction, tiebreak => direction)

    if (cursor = decode_cursor(params[:cursor]))
      comparator = direction == :desc ? "<" : ">"
      scope = scope.where(
        "(#{table}.#{order_col}, #{table}.#{tiebreak_col}) #{comparator} (?, ?)",
        cursor[:value], cursor[:id]
      )
    end

    limit = pagination_limit
    records = scope.limit(limit + 1).to_a

    next_cursor = nil
    if records.size > limit
      records = records.first(limit)
      last = records.last
      next_cursor = encode_cursor(last.public_send(order_column), last.public_send(tiebreak))
    end

    [records, next_cursor]
  end

  private

  def pagination_limit
    requested = params[:limit].to_i
    return DEFAULT_LIMIT if requested <= 0

    [requested, MAX_LIMIT].min
  end

  def encode_cursor(value, id)
    payload = { "v" => value.is_a?(Time) ? value.iso8601(6) : value, "id" => id }
    Base64.urlsafe_encode64(JSON.generate(payload), padding: false)
  end

  def decode_cursor(raw)
    return nil if raw.blank?

    payload = JSON.parse(Base64.urlsafe_decode64(raw))
    { value: payload["v"], id: payload["id"] }
  rescue ArgumentError, JSON::ParserError
    nil # a malformed cursor is treated as "start from the beginning"
  end
end
