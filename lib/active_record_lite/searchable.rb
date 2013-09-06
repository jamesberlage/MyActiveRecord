require_relative './db_connection'

module Searchable
  def where(params)
    keys = params.keys.map { |key| "#{key} = ?" }

    DBConnection.execute(<<-SQL, *params.values)
      SELECT
        *
      FROM
        #{self.table_name}
      WHERE
        #{keys.join(" AND ")}
    SQL
  end
end