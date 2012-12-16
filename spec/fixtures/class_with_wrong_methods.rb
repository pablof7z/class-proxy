class ClassWithWrongMethods
  include ClassProxy

  attr_accessor :name

  proxy_methods :invalid_name
end