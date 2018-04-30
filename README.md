# Chefspec::Ohai

Traditionally if you have developed Ohai plugins for Chef you have had to test
them on the node after they have been deployed. If they have failed during the
deployment you will not see an error and instead see no data within the node
object. This is tiring, confusing, and makes it difficult to practice
test-driven development within regard to Ohai plugins.

The ability to test your Ohai plugins locally with RSpec has always been possible
if you understand how Ohai finds and loads plugins. This gem simplifies this
process and provides a number of helpers and methods to make it express your
expectations about your Ohai plugin.

> This gem is called ChefSpec::Ohai but it does not need ChefSpec to work. It
> relies solely on RSpec. However, when you are working with testing your
> cookbooks you are often using ChefSpec so it seemed like naming as an extension
> to ChefSpec was the right idea.

## Installation

Installation on your local workstation will require that you have this gem
installed. To do that you can create a Gemfile for your cookbook and then perform
the following:

Create a Gemfile and then add this line to your cookbook's Gemfile:

```ruby
gem 'chefspec-ohai'
```

And then execute:

    $ chef exec bundle

Or install it yourself as:

    $ chef exec gem install chefspec-ohai

## Usage

Define your plugin within your cookbook in `cookbook/files/httpd_modules.rb`:

```ruby
Ohai.plugin(:Apache) do
  provides 'apache/modules'

  collect_data(:default) do
    apache Mash.new
    modules_cmd = shell_out('apachectl -t -D DUMP_MODULES')
    apache[:modules] = modules_cmd.stdout
  end
end
```

First, you will want to load the helpers within `spec/spec_helper.rb` file:

```ruby
require 'chefspec'            # Auto-generated with cookbook
require 'chefspec/berkshelf'  # Auto-generated with cookbook
require 'chefspec/ohai'       # Added by YOU if you want to use this gem
```

Now you will want to write a specification that will test your Ohai plugin. There
is currently no convention and no requirements for where you store your ohai
plugin tests within the cookbook. I have chosen to create the directory
`spec/unit/plugins`.

I often choose to name the specification after the name of the file that stores
the Ohai plugin. I were testing an Ohai plugin stored in `files/default/httpd_modules.rb`
I would create a specification named `spec/unit/plugins/httpd_modules_spec.rb`.
The most important thing is that the file ends with `_spec.rb` so that RSpec
will automatically find this file and load it appropriately.

Within the specification file that you need to require the content found in the
`spec/spec_helper.rb`. This will ensure that this gem is loaded prior to this
file being evaluated.

This gem provides an alias of RSpec's `describe` named `describe_ohai_plugin`
which loads some additional helper methods to assist you with expressing your
examples and the expectations within your examples.

Here is a sample specification file that asserts that an Ohai plugin provides
particular attributes and those attributes, when run (and stubbing the environment),
are set properly.

```ruby
require 'spec_helper'

describe_ohai_plugin :Apache do
  let(:plugin_file) { 'files/default/httpd_modules.rb' }

  context 'default collect data' do
    it "provides 'apache/modules'" do
      expect(plugin).to provide_attribute('apache/modules')
    end

    it "correctly captures output" do
      allow(plugin).to receive(:shell_out).with('apachectl -t -D DUMP_MODULES') { double(stderror: 0, stdout: 'unit tests do not like to run on systems') }
      expect(plugin_attribute('apache/modules')).to eq('unit tests do not like to run on systems')
    end
  end
end
```

Run the tests within the cookbook directory:

```
$ rspec
..
Finished in 0.04775 seconds (files took 3.38 seconds to load)
2 examples, 0 failures
```

## Testing other than the `collect_data :default`

A plugin may collect data on different platforms. For example the following plugin:

```ruby
Ohai.plugin(:NonDefaultCollectData) do
  provides 'application/version'

  collect_data(:linux) do
    application Mash.new
    application[:version] = '3.0.0'
  end

  collect_data(:windows) do
    application Mash.new
    application[:version] = '9.0.0'
  end
end
```

You write tests for each platform:

```ruby
context 'linux data collection' do
  let(:platform) { 'linux' }

  it 'the attribute is correctly set' do
    expect(plugin_attribute(attribute_name)).to eq '3.0.0'
  end
end

context 'windows data collection' do
  let(:platform) { 'windows' }

  it 'the attribute is correctly set' do
    expect(plugin_attribute(attribute_name)).to eq '9.0.0'
  end
end
```

## Ohai plugins written as Cookbook Templates

Ohai plugins that are templates and not cookbook files require a little more setup. As templates require the presence of template variables or the node object that are passed to the temple you will need to define another helper in your specification `template_variables`.

The following plugin defined in a template `templates/httpd_modules.rb.erb`:

```ruby
Ohai.plugin(:Apache) do
  provides 'apache/modules'

  collect_data(:default) do
    puts "<%= @template_variable %>"
    puts "<%= node['attribute'] %>"
    apache Mash.new
    modules_cmd = shell_out('apachectl -t -D DUMP_MODULES')
    apache[:modules] = modules_cmd.stdout
  end
end
```

Using a template for a plugin requires that you provide the template variables to
populate.


```ruby
require 'spec_helper'

describe_ohai_plugin :Apache do
  let(:plugin_file) { 'templates/apache_modules.rb.erb' }

  let(:template_variables) do
    { template_variable: 'Free Me!', node: { 'attribute' => 'something' } }
  end

  context 'default collect data' do
    it "provides 'apache/modules'" do
      expect(plugin).to provide_attribute('apache/modules')
      # OR
      expect(plugin).to provides_attribute('apache/modules')
    end

    it 'correctly captures output' do
      allow(plugin).to receive(:shell_out).with('apachectl -t -D DUMP_MODULES') { double(stderror: 0, stdout: 'unit tests do not like to run on systems') }
      expect(plugin_attribute('apache/modules')).to eq('unit tests do not like to run on systems')
    end
  end
end
```

## Testing a plugin with a dependency on another plugin

A plugin may have a dependency on another plugin. A plugin may be defined as:

```ruby
Ohai.plugin(:FirstNetwork) do
  provides 'first_network/ipv4', 'first_network/interface'

  depends 'other_plugin'

  collect_data(:default) do
    first_network Mash.new

    name, data = network['interfaces'].first
    first_network[:interface] = name
    first_network[:ipv4] = data['addresses'].first.first
  end
end
```

Within the test you can write expectations that the the plugin has a dependency on the plugin. When it comes to creating the test data, that requires stubbing the plugin calls to the dependent content.

```ruby

describe_ohai_plugin :FirstNetwork do
  let(:plugin_file) { 'files/first_network.rb' }

  it 'provides the first network address' do
    expect(plugin).to provide_attribute('first_network/ipv4')
  end

  it 'provides the first network interface' do
    expect(plugin).to provide_attribute('first_network/interface')
  end

  it 'depends on another plugin' do
    expect(plugin).to depend_on_attribute('network')
  end

  context 'default data collection' do
    before do
      allow(plugin).to receive(:network).and_return(network_data)
    end

    let(:network_data) do
      {
        'interfaces' => {
          'lo' => {
            'state' => 'unknown',
            'addresses' => {
              '127.0.0.1' => {
                'family' => 'inet'
              }
            }
          }
        }
      }
    end

    it 'the first network interface is correctly set' do
      expect(plugin_attribute('first_network/interface')).to eq('lo')
    end

    it 'the first network address is correctly set' do
      expect(plugin_attribute('first_network/ipv4')).to eq('127.0.0.1')
    end
  end
```

## Development

This gem only provides a subset of the features that are possible to specify when
defining an Ohai plugin. I encourage you to open issues and pull-requests to
enhance this project.

After checking out the repo, run `bin/setup` to install dependencies. Then, run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release` to create a git tag for the version, push git commits and tags, and push the `.gem` file to [rubygems.org](https://rubygems.org).

## Contributing

1. Fork it ( https://github.com/[my-github-username]/chefspec-ohai/fork )
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create a new Pull Request
