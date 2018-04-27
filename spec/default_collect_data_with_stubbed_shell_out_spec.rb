require 'spec_helper'

describe_ohai_plugin :DefaultCollectDataWithStubbedShellOut do
  let(:plugin_file) { 'spec/fixtures/default_collect_data_with_stubbed_shell_out_plugin.rb' }

  context 'when the plugin attribute defined in the test exists in the the plugin definition' do
    let(:plugin_attribute_that_exists) { 'apache/modules' }

    it 'the `provide_attribute` matcher passes' do
      expect(plugin).to provides_attribute(plugin_attribute_that_exists)
    end

    it 'the negated case of the `plugin_attribute` matcher fails with helpful error message' do
      expected_error_msg = "Expected the plugin to NOT provide '#{plugin_attribute_that_exists}'. Plugin's defined attributes: '#{plugin_attribute_that_exists}'"

      begin
        expect(plugin).not_to provides_attribute(plugin_attribute_that_exists)
      rescue Exception => e
        expect(e.message).to eq(expected_error_msg)
      end
    end
  end

  context 'when the plugin attribute defined in the test does not exist in the plugin definition' do
    it 'the negated case of `provide_attribute` matcher passes' do
      expect(plugin).not_to provide_attribute('undefined')
    end

    it 'the positive case of the `plugin_attribute` matcher fails with helpful error message' do
      expected_error_msg = "Expected the plugin to provide 'apache/static/modules'. Plugin's defined attributes: 'apache/modules'"

      begin
        expect(plugin).to provide_attribute('apache/static/modules')
      rescue Exception => e
        expect(e.message).to eq(expected_error_msg)
      end
    end
  end

  context 'default data collection' do
    context 'stubbed `shell_out` command' do
      let(:stubbed_command) { 'apachectl -t -D DUMP_MODULES' }
      let(:stubbed_output) { 'unit tests do not like to run on systems' }

      before :each do
        allow(plugin).to receive(:shell_out).with(stubbed_command) { double(stdout: stubbed_output) }
      end

      describe 'the `plugin_attribute` helper' do
        context 'with an attribute that exists' do
          it 'returns the expected stubbed results' do
            expect(plugin_attribute('apache/modules')).to eq(stubbed_output)
          end
        end

        context 'with an attribute that does NOT exist' do
          context 'that is a sibling to an attribute that does exist' do
            let(:undefined_mash_key) { 'apache/undefined_key' }

            it 'returns a nil value' do
              # This is expected behavior. The base-level key is set up as a
              #   Mash (essentially a Hash with string or symbol access), so
              #   any other keys specified are misses and will return nil values.
              expect(plugin_attribute(undefined_mash_key)).to eq(nil)
            end
          end

          context 'that is in a completely different attribute path' do
            let(:undefined_attribute) { 'apache/modules/static/ssl' }

            it 'fails with a helpful error message' do
              expected_error_message = "Plugin does not define attribute path '#{undefined_attribute}'. Does the definition or test have a misspelling? Does the plugin properly initialize the entire attribute path?"

              begin
                expect(plugin_attribute(undefined_attribute)).to eq nil
              rescue Exception => e
                expect(e).to be_kind_of(PluginAttributeUndefinedError)
                expect(e.message).to match("#{expected_error_message}\n\nPlugin Attribute Data:\n#{ {'apache' => plugin.apache}.to_yaml }\n---")
              end
            end
          end
        end

      end
    end
  end
end
