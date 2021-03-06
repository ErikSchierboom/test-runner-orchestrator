module Orchestrator
  class SPIClient

    def self.fetch_languages
      url = "#{spi_adddress}/test_runner/languages"
      JSON.parse(RestClient.get(url))["languages"]
    end

    def self.fetch_submissions_to_test
      url = "#{spi_adddress}/test_runner/submissions_to_test"
      JSON.parse(RestClient.get(url))["submissions"]
    end

    def self.post_test_run(submission_uuid, status_code, status_message, results)
      url = "#{spi_adddress}/test_runner/submission_tested/#{submission_uuid}"
      RestClient.post(url, {
        ops_status: status_code,
        ops_message: status_message,
        results: results
      })
    end

    def self.post_unknown_error(submission_uuid, message)
      url = "#{spi_adddress}/test_runner/submission_tested/#{submission_uuid}"
      RestClient.post(url, {
        ops_status: 500,
        ops_message: "An unknown error occurred. The exception message was: #{message}"
      })
    end

    private

    def self.spi_adddress
      @spi_adddress ||= secrets['spi_address']
    end

    def self.secrets
      @secrets ||= YAML::load(ERB.new(File.read(File.dirname(__FILE__) + "/../../config/secrets.yml")).result)[Orchestrator.env]
    end
  end

end

