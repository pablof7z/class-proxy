class-proxy
===========

A generic (yet ActiveRecord compliant) class proxy to setup proxy methods for your classes.

## Using

The `ClassProxy` module just needs to be included in a class to get the capabilities
provided by this gem.

### Example

```ruby
class UserDb
  include MongoMapper::Document
  include ClassProxy

  primary_fetch  { |args| where(args).first or (raise NotFound) }
  fallback_fetch { |args| Octokit.user(args[:username]) }
  after_fallback_fetch { |obj| UserDb.new(username: obj.login) }

  key :name, String
  key :reverse_name, String
  key :username, String
  key :public_repos, String
  key :username_uppercase, String

  # Use fallback_fetch since obj is requested
  proxy_methods reverse_name: lambda { |obj| obj.name.reverse }

  # No obj in the lambda, use the UserDb#username method here
  proxy_methods username_uppercase: lambda { username.upcase }
end
```

With this class now the following can be done:

```ruby
> user = UserDb.fetch(username: 'heelhook')
=> #<UserDb _id: 779813, name: "Pablo Fernandez", public_repos: "25", username: "heelhook">
```

Since `Octokit.user` returned an object which responded to `name` and our `UserDb` class
has a corresponding attribute, `:name` was set for us.

```ruby
> user.name
=> "Pablo Fernandez"
```

Yet `reverse_name` is not included, so when we call it, the `proxy_method` associated with it
is used.

```ruby
> user.reverse_name
=> "zednanreF olbaP"
```

Since that `proxy_method`'s `lambda` requested an `|obj|`, the method `fallback_fetch` was used
and the object returned is used for `obj.name.reverse`

#### Using `proxy_methods` without new `fallback_fetch` calls

Let's see what's currently loaded.

```ruby
> user.no_proxy_username_uppercase
=> nil
```

Using the proxy. We already have the username in our object, so our `username_uppercase` proxy method will
just use that (no `|obj|` is used).

```ruby
> user.username_uppercase
=> "HEELHOOK"
```

#### Saving

Here the `fallback_fetch` will not be used since the object has been persisted.

```ruby
> user.save
=> true
> user = UserDb.fetch(username: 'heelhook')
=> #<UserDb _id: 779813, name: "Pablo Fernandez", public_repos: "25", username: "heelhook">
```

Like any

## Compatibility

ClassProxy is tested against MRI 1.9.3.

## Credits

Pablo Fernandez: heelhook at littleq . net

## Contributing

Once you've made your great commits:

1. Fork
2. Create a topic branch - `git checkout -b my_branch`
3. Push to your branch - `git push origin my_branch`
4. Create a [Pull Request](https://help.github.com/pull-requests/) from your branch
5. That's it!

## License

Copyright (c) 2012 Pablo Fernandez

Permission is hereby granted, free of charge, to any person obtaining
a copy of this software and associated documentation files (the
"Software"), to deal in the Software without restriction, including
without limitation the rights to use, copy, modify, merge, publish,
distribute, sublicense, and/or sell copies of the Software, and to
permit persons to whom the Software is furnished to do so, subject to
the following conditions:

The above copyright notice and this permission notice shall be
included in all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE
LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION
OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION
WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
