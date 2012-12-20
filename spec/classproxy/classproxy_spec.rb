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

  context "with no fallback post processor" do
    let (:klass) { SimpleClass }
    let (:user) { klass.fetch(login: login)}

    it "finds someone" do
      user.class.should == klass
    end

    it "the user has the right login" do
      user.login.should == login
    end
  end

  context "explicitly skip existent fallback" do
    let (:user) { klass.fetch({username: login}, {skip_fallback: true})}

    it "doesn't find someone" do
      user.should be_nil
    end
  end

  context "with an invalid class definition" do
    it "errors when a class has wrong methods" do
      expect {
        load 'fixtures/class_with_wrong_methods'
        ClassWithWrongMethods
      }.to raise_error LoadError
    end
  end

  context "manually created with some fields and not others" do
    let (:klass) { SimpleClass }
    let (:user) do
      u = klass.new
      u.login = login
      u
    end

    it "has a login" do
      user.login.should == login
    end

    it "doesn't have a name loaded" do
      user.no_proxy_name.should be_nil
    end

    it "lazy loads the name when requested" do
      user.name.should_not be_nil
    end

    it "doesn't have a name loaded again" do
      user.name = 'my made up name'
      user.name.should == 'my made up name'
    end

    it "respects proxy_methods that mix default procs and customized procs" do
      user.uppercase_login.should == user.login.upcase
    end

    it "calls the last version of an overwritten proxy_method" do
      user.followers.should == 'second version'
    end
  end

  context "default fallback returns nil values" do
    let (:klass) do
      t = double
      t.should_receive(:respond_to?).and_return(true)
      t.should_receive(:keys).at_least(1).times.and_return([:method1, 'method2'])
      t.should_receive(:method1).and_return('with value')
      t.should_receive(:method2).exactly(1).times.and_return(nil)

      Class.new do
        include ClassProxy

        fallback_fetch {|args| t }

        attr_accessor :method1, :method2, :method3

        proxy_methods :method1, :method2, :method3
      end
    end
    let (:object) { klass.new }

    it "is an object with nilled attributes" do
      object.no_proxy_method1.should be_nil
      object.method1
      object.method2
    end

    it "comes back with a value for the method that has something" do
      object.method1.should_not be_nil
    end

    it "comes back with nothing for the method that has nothing but doesn't instist on calling it" do
      object.method2.should be_nil
      object.method2.should be_nil
    end

    it "doesn't run the default fallback when it has already done so for any method with no custom proxy method fallback" do
      object.method1
      object.method3
    end
  end

  context "custom fallback" do
    context "returns nil values" do
      let (:klass) do
        custom_fallback = double
        custom_fallback.should_receive(:value).exactly(1).times.and_return(nil)

        Class.new do
          include ClassProxy

          attr_accessor :custom

          proxy_methods custom: lambda { custom_fallback.value }
        end
      end
      let (:object) { klass.new }

      it "caches the response of an overriden proxy method declaration when nil" do
        object.custom.should be_nil
        object.custom.should be_nil
      end
    end

    context "returns not nil values" do
      let (:klass) do
        custom_fallback = double
        custom_fallback.should_receive(:value_not_nil).exactly(1).times.and_return(true)

        Class.new do
          include ClassProxy

          attr_accessor :custom

          proxy_methods custom: lambda { custom_fallback.value_not_nil }
        end
      end
      let (:object) { klass.new }

      it "caches the response of an overriden proxy method" do
        object.custom.should_not be_nil
        object.custom.should_not be_nil
      end
    end

    context "requests a fallback to default" do
      let (:klass) do
        Class.new do
          include ClassProxy

          fallback_fetch { |args| Hashie::Mash.new(method2: self.method1) }

          attr_accessor :method1, :method2

          proxy_methods :method1
          proxy_methods method2: lambda { raise ClassProxy::NotFound }
        end
      end
      let (:object) do
        o = klass.new
        o.method1 = 'has a value'
        o
      end

      it "has a value on method1" do
        object.method1.should_not be_nil
      end

      it "gets a value for a method that requests a fallback" do
        object.method2.should_not be_nil
      end
    end
  end
end