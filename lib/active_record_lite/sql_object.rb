require_relative './associatable'
require_relative './db_connection'
require_relative './mass_object'
require_relative './searchable'

class SQLObject < MassObject
  extend Searchable
  extend Associatable

  def self.set_table_name(table_name)
    instance_variable_set(:@table_name, table_name)
  end

  def self.table_name
    @table_name
  end

  def self.all
    rows = DBConnection.execute("SELECT * FROM #{self.table_name}")
    self.parse_all(rows)
  end

  def self.find(id)
    rows = DBConnection.execute("SELECT * FROM #{self.table_name} WHERE id = ?", id)
    self.parse_all(rows).first
  end

  def create
    attr_names = self.class.attributes.join(", ")
    q_marks = self.class.attributes.map { "?" }.join(", ")

    DBConnection.execute("INSERT INTO #{self.class.table_name} (#{attr_names}) VALUES (#{q_marks})", *attribute_values)
  end

  def update
    attr_names = self.class.attributes.map do |attribute|
      "#{attribute} = ?"
    end.join(", ")

    DBConnection.execute("UPDATE #{self.class.table_name} SET #{attr_names} WHERE id = ?", *attribute_values, self.id)
  end

  def save
    self.id.nil? ? create : update
  end

  def attribute_values
    self.class.attributes.map { |attribute| instance_variable_get("@#{attribute}") }
  end
end
