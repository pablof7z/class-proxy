require "mongo_mapper"
require "classproxy"
require "bundler"

Bundler.require(:test, :default)

EphemeralResponse.activate

MongoMapper.database = 'classproxy-test'

def reset_databases
  MongoMapper.connection.drop_database MongoMapper.database.name
end
