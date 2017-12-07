require "chefspec/ohai/version"

RSpec.configure do |config|
  #
  # Add a convienent name for the example group to the RSpec lexicon. This
  # allows a user to write:
  #     'desribe_ohai_plugin :Apache'.
  #
  # As opposed to appending a type to the declaration of the spec:
  #   'describe :Apache, type: :ohai_plugin'
  #
  config.alias_example_group_to :describe_ohai_plugin, type: :ohai_plugin
end

# This defines the shared context with all the helper methods
shared_context 'Ohai Plugins', type: :ohai_plugin do

  # The plugin helper will take the symbol name provided as the subject to the
  # describe and create the Ohai plugin class and then instantiate that class
  # for use within the specifications.
  let(:plugin) do
    ohai_plugin_class = Ohai.plugin(subject) {}
    ohai_plugin_class.new(plugin_data)
  end

  # When an Ohai plugin is created there is a Hash of data that must be provided.
  # It is likely not important to provide data but allowing it to be overriden
  # here if necessary.
  let(:plugin_data) { Hash.new }

  # Loads the plugin source from the specified plugin_file helper
  let(:plugin_source) do
    source = File.read(plugin_file)
    if plugin_file.start_with?('templates')
      ERB.new(source).result(plugin_template_binding)
    else
      source
    end
  end

  # This helper is required to be defined by any Ohai plugin that is defined
  # as a template. This hash of values will used to create the instance variables
  # and define the conents of the node object which are used when generating the
  # resulting template.
  let(:template_variables) do
    raise %(
When you define a plugin_source based on a template a hash of template variables needs to be provided.

Example:
    let(:template_variables) do
      { name: 'value_inserted_into_plugin', node: { 'ipaddress' : '127.0.0.1' } }
    end
 )
  end

  # Return a binding created with the hash of values defined in the template_variables
  # helper.
  let(:plugin_template_binding) do
    PluginBinding.new(template_variables).expose_binding!
  end


  # To provide a space to instance variables that will be used by any Ohai
  # plugins that use ERB templating to insert content.
  class PluginBinding

    # Create a new object that will define instance variables out of the hash's
    # key-value pairs. This will create a safe place to define instance variables
    # within a binding that can used when rendering the content of the ERB.
    def initialize(template_variables)
      Hash(template_variables).each do |key,value|
        instance_variable_set("@#{key}",value)
      end
    end

    # Within a template you can use `node[:attribute]`. This method provides
    # support for that by creating this method that maps to the @node instance
    # variable. This means that if you want to define a Ohai plugin that uses
    # the node object and test it, then you are required to provide the values
    # to make that work for the test.
    #
    # NOTE: A consideration here would be to use Fauxhai instead of requiring a
    #       user to provide each attribute. This would get time consumsing to
    #       create tests if the Ohai plugin used a lot of node attributes.
    def node
      if @node.nil?
        raise NoNodeDataProvidedToTemplatePlugin
      end
      @node
    end

    # This exposes the private #binding method to allow it to be used as the specified
    # binding when parsing ERB template.
    def expose_binding!
      binding
    end

    class NoNodeDataProvidedToTemplatePlugin < StandardError

      def message
        "The Ohai plugin attempted to retrieve an attribute from the `node` object. However, no node attributes were defined in in the template_variables helper.
Add a template_variables helper within your ohai plugin specification and include a `node` key that returns the data you need to satisfy the requirements of your plugin.

Example:
    let(:template_variables) do
      { node: { 'ipaddress' => '127.0.0.1' } }
    end"
      end
    end

  end

  # Determine the plugin_path from the specified plugin_file
  let(:plugin_path) { File.dirname(plugin_file) }
  # This helper defines the path to the plugin file. This must be specified
  # by the author of the specification. Without specifying it, overriding this
  # helper, an error is raised informing them that it must be specifed and
  # provides an example to get them started.
  let(:plugin_file) do
    raise %(
Please specify the path to the Ohai plugin file within this cookbook.

Example:
    let(:plugin_file) { "files/default/httpd_modules.rb" }
 )
  end

  # A Loader requires a controller. This controller may need to be overriden so
  # it is provided as a helper.
  let(:plugin_controller) { double('plugin_controller') }
  # The plugin_loader will evaluate the source of the plugin with the controller
  let(:plugin_loader) { Ohai::Loader.new(plugin_controller) }

  #
  # Before each example we want to load the plugin from source. This asks the
  # plugin_loader to load the plugin from the specifed source and path and
  # evalute the contents as a version 7 ohai plugin.
  #
  before :each do
    capture_named_plugins!
    ps = plugin_source
    pp = plugin_path
    plugin_loader.instance_eval { load_v7_plugin_class(ps,pp) }
  end

  after :each do
    restore_named_plugins!
  end


  # Ohai plugins are defined with a class, which is a constant, and
  # they are added to the this module. Capture any currently loaded
  # plugins before we add any new plugins.
  def capture_named_plugins!
    @named_plugins = Ohai::NamedPlugin.constants
  end

  # Examine the current list of plugins loaded and compare it to
  # what was found when we started. Remove all the plugins that
  # have been added since then.
  def restore_named_plugins!
    diff_plugins = Ohai::NamedPlugin.constants - @named_plugins
    diff_plugins.each do |plugin|
      Ohai::NamedPlugin.send(:remove_const,plugin)
    end
  end

  # This provides a new matcher when wanting to make assertions that the plugin
  # does provide the correct body of attributes. The Ohai plugin class returns
  # an array of attributes that it provides through `#provides_attrs` which
  # is evaluated to ensure that the expected value is within that list.
  RSpec::Matchers.define :provides_attribute do |expected|
    match do |plugin|
      expect(plugin.class.provides_attrs).to include(expected)
    end
  end

  # Provides a simplier way to stub out the shell_out that is probably going on
  # within the Ohai plugin.
  def stub_plugin_shell_out(command,result)
    allow(plugin).to receive(:shell_out).with(command) { double(stdout: result) }
  end

  # To make the process of verifying the attributes a little more streamlined
  # you can use this helper to request the attributes from the plugin itself.
  #
  # The attributes are not loaded into the plugin until the plugin is run.
  # Then the plugin will provide a top-level method that matches the first
  # element in the ohai 'provides' String.
  #
  # The remaining elements within the 'provides' are elements within the Mash
  # that must be traversed to get to the value desired. That is done here and
  # then returned.
  def plugin_attribute(attribute)
    plugin.run

    components = attribute.split('/')
    top_level_mash_name = components.first
    attributes = components[1..-1]

    top_level_mash = plugin.send(top_level_mash_name)
    attributes.inject(top_level_mash) { |mash,child| mash[child] }
  end

end
