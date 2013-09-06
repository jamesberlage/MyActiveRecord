require 'active_support/core_ext/object/try'
require 'active_support/inflector'
require_relative './db_connection.rb'

class AssocParams
  def underscore_to_camelcase(word)
    word.split('_').map { |word| word.capitalize }.join('')
  end

  def add_underscored_words(original, *new_words)
    ([original] + new_words).join("_")
  end

  def other_class
    @class_name.constantize
  end

  def other_table
    @class_name.downcase + 's'
  end
end

class BelongsToAssocParams < AssocParams
  attr_accessor :class_name, :foreign_key, :primary_key

  def initialize(name, params)
    @class_name = params.include?(:class_name) ? params[:class_name].to_s : underscore_to_camelcase(name.to_s)
    @foreign_key = params.include?(:foreign_key) ? params[:foreign_key].to_s : add_underscored_words(name.to_s, "id")
    @primary_key = params.include?(:primary_key) ? params[:primary_key].to_s : "id"
  end

  def type
  end
end

class HasManyAssocParams < AssocParams
  attr_accessor :class_name, :foreign_key, :primary_key

  def initialize(name, params)#, self_class)
    @class_name = params.include?(:class_name) ? params[:class_name].to_s[0..-2] : underscore_to_camelcase(name.to_s)[0..-2]
    @foreign_key = params.include?(:foreign_key) ? params[:foreign_key].to_s : add_underscored_words(name.to_s, "id")
    @primary_key = params.include?(:primary_key) ? params[:primary_key].to_s : "id"
  end

  def type
  end
end

module Associatable
  def assoc_params
    @assoc_params ||= {}
  end

  def belongs_to(name, params = {})
    define_method(name) do
      aps = BelongsToAssocParams.new(name, params)
      foreign_key_value = self.send(aps.foreign_key)

      results = DBConnection.execute("SELECT * FROM #{aps.other_table} WHERE #{aps.primary_key} = ?", foreign_key_value)
      aps.other_class.parse_all(results).first
    end

    assoc_params[name] = BelongsToAssocParams.new(name, params)
  end

  def has_many(name, params = {})
    define_method(name) do
      aps = HasManyAssocParams.new(name, params)
      primary_key_value = self.send(aps.primary_key)

      results = DBConnection.execute("SELECT * FROM #{aps.other_table} WHERE #{aps.foreign_key} = ?", primary_key_value)
      aps.other_class.parse_all(results)
    end
  end

  def has_one_through(name, assoc1, assoc2)
    define_method(name) do
      assoc1params = self.class.assoc_params[assoc1]
      assoc2params = assoc1.to_s.capitalize.constantize.assoc_params[assoc2]

      foreign_key_value = self.send(assoc1params.primary_key)

      results = DBConnection.execute(<<-SQL, foreign_key_value)
        SELECT
          assoc2.*
        FROM
          #{assoc2params.other_table} AS assoc2
        JOIN
          #{assoc1params.other_table} AS assoc1
        ON
          assoc2.#{assoc2params.primary_key} = assoc1.#{assoc2params.foreign_key}
        WHERE
          assoc1.#{assoc1params.primary_key} = ?
      SQL
      assoc2params.other_class.parse_all(results).first
    end
  end
end
