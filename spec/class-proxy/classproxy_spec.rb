require 'spec_helper'
require 'fixtures/classes'

describe ClassProxy do
  before :each do
    reset_databases
  end

  let (:klass) { UserDb }
  let (:model) { klass.new }
  let (:login) { "heelhook" }

  it { klass.should respond_to :primary_fetch }
  it { klass.should respond_to :fallback_fetch }
  it { klass.should respond_to :after_fallback_fetch }
  it { klass.should respond_to :fetch }

  context "lazy loading" do
    let (:user) { klass.new(username: login) }

    it "has a user with a username" do
      user.username.should_not be_nil
    end

    it "doesn't have a name when skipping proxing" do
      user.no_proxy_person_name.should be_nil
    end

    it "has a name when using the proxy" do
      user.person_name.should_not be_nil
    end
  end

  context "fetching" do
    let (:user) { klass.fetch(username: login) }
    let (:saved_user) { user.save.reload }

    it "finds a user" do
      user.should_not be_nil
    end

    it "sets defaults keys" do
      user.person_name.should_not be_nil
    end

    it "sets after_fallback_fetch keys" do
      user.username.should == login
    end

    it "uses fallback methods overwriters" do
      user.username_uppercase.should == login.upcase
    end

    it "lazy loads undefined attributes using proxy_methods" do
      user.public_repos.should_not be_nil
    end
  end

  context "no fallback post processor" do
    let (:klass) { SimpleClass }
    let (:user) { klass.fetch(login: login)}

    it "finds someone" do
      user.class.should == klass
    end

    it "the user has the right login" do
      user.login.should == login
    end
  end
end