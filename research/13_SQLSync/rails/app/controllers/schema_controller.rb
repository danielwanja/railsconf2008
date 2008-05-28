class SchemaController < ApplicationController
  
  def standard_dump
    ActiveRecord::Base.schema_format = :sql
    stream = StringIO.new
    ActiveRecord::SchemaDumper.ignore_tables = []
    ActiveRecord::SchemaDumper.dump(ActiveRecord::Base.connection, stream)
    render :text => stream.string
  end
  
end
