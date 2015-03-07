require_relative 'db_connection'
require 'active_support/inflector'
# NB: the attr_accessor we wrote in phase 0 is NOT used in the rest
# of this project. It was only a warm up.

class SQLObject
  def self.columns
    result = DBConnection.execute2(<<-SQL)
      SELECT
        *
      FROM
        "#{table_name}"
    SQL

    result[0].map { |col| col.to_sym }
  end

  def self.finalize!
    columns.each do |col|
      define_method("#{col}=") do |arg|
        attributes[col] = arg
      end

      define_method(col) do
        attributes[col]
      end
    end
  end

  def self.table_name=(table_name)
    @table_name = table_name
  end

  def self.table_name
    @table_name ||= self.to_s.tableize
  end

  def self.all
    results = DBConnection.execute(<<-SQL)
      SELECT
        *
      FROM
        "#{table_name}"
    SQL

    parse_all(results)
  end

  def self.parse_all(results)
    objects = results.map do |result|
      self.new(result)
    end

    objects
  end

  def self.find(id)
    result = DBConnection.execute(<<-SQL)
      SELECT
        *
      FROM
        "#{table_name}"
      WHERE
        "#{table_name}".id = "#{id}"
    SQL

    result.empty? ? nil : parse_all(result)[0]
  end

  def initialize(params = {})
    params.each do |name, value|
      name_sym = name.to_sym

      unless self.class.columns.include?(name_sym)
        raise "unknown attribute '#{name}'"
      end

      send("#{name_sym}=", value)
    end
  end

  def attributes
    @attributes ||= {}
  end

  def attribute_values
    self.class.columns.map do |col_name|
      send(col_name)
    end
    # attributes.values
  end

  def insert
    col_names = self.class.columns
    question_marks = "?, " * (col_names.length - 1) + "?"
    col_names = col_names.join(", ")
    print attribute_values
    DBConnection.execute(<<-SQL, *attribute_values)
      INSERT INTO
        "#{self.class.table_name}" (#{col_names})
      VALUES
        (#{question_marks})
    SQL

    self.id = DBConnection.last_insert_row_id
  end

  def update
    col_string = self.class.columns.map do |col|
      "#{col} = ?"
    end.join(", ")
    DBConnection.execute(<<-SQL, *attribute_values)
      UPDATE
        "#{self.class.table_name}"
      SET
        #{col_string}
      WHERE
        id = #{self.id}
    SQL
  end

  def save
    self.id.nil? ? insert : update
  end
end
