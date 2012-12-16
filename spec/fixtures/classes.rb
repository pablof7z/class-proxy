class UserDb
  include MongoMapper::Document
  include ClassProxy

  primary_fetch { |args| where(args).first or (raise NotFound) }
  fallback_fetch { |args| Octokit.user(args[:username]) }
  after_fallback_fetch { |model, obj| model.username = obj.login }

  key :person_name, String
  key :username, String
  key :public_repos, String
  key :username_uppercase, String

  proxy_methods person_name: lambda { |obj| obj.name }
  proxy_methods username_uppercase: lambda { username.upcase }
end

class UserNoDb
  include ClassProxy

  fallback_fetch { |args| Octokit.user(args[:login]) }

  attr_accessor :name, :login, :repositories

  proxy_methods repositories: lambda { Octokit.repos(login) }
end

class SimpleClass
  include ClassProxy

  fallback_fetch { |args| Octokit.user(args[:login]) }

  attr_accessor :name, :followers, :login, :uppercase_login

  proxy_methods :name, :followers, uppercase_login: lambda { login.upcase }
end
