require 'spec_helper'
require 'fixtures/classes'

describe ClassProxy do
  it "has a version" do
    ClassProxy::VERSION.should_not be_nil
  end
end