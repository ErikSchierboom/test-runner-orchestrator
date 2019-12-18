require_relative 'base'

module Orchestrator
  class ChangeSettingsTest < SystemBaseTestCase
    def test_updates_successfully
      application = Orchestrator.application
      application.add_language(:ruby, {"num_processors" => 0})

      timeout = 30002
      version = "some version"

      patch '/languages/ruby/settings', {
        settings: {
          timeout_ms: timeout,
          container_version: version
        }
      }

      assert_equal 200, last_response.status

      application.send(:borrow_language, :ruby) do |lang|
        settings = lang.send(:settings)
        assert_equal timeout, settings.timeout_ms
        assert_equal version, settings.container_version
      end
    end
  end
end
