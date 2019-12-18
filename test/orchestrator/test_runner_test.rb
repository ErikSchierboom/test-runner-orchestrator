require 'test_helper'

module Orchestrator
  class TestRunnerTest < Minitest::Test
    def test_uses_submission_container_slug
      stub_spi_client!

      language = :ruby
      exercise = :bob
      uuid = "023949s9dads"
      s3_uri = "s3://test-exercism-submissions/test/testing/#{uuid}"
      timeout = 2000

      container_slug = "git-123asd"
      submission = Submission.new(uuid, language, exercise, container_slug)

      success_data = JSON.parse({status: {status_code: 200}}.to_json)
      conn = mock
      conn.expects(:run_tests).with(language, exercise, s3_uri, container_slug, timeout).returns(success_data)

      test_runner = TestRunner.new(submission, conn, mock(timeout_ms: timeout))
      test_runner.test!
    end

    def test_uses_default_container_slug
      stub_spi_client!

      language = :ruby
      exercise = :bob
      uuid = "023949s9dads"
      s3_uri = "s3://test-exercism-submissions/test/testing/#{uuid}"

      submission_with_nil = Submission.new(uuid, language, exercise, nil)
      submission_with_blank = Submission.new(uuid, language, exercise, "")
      submission_with_none = Submission.new(uuid, language, exercise)

      container_slug = "git-123asd"
      timeout = 2000

      success_data = JSON.parse({status: {status_code: 200}}.to_json)
      conn = mock
      conn.expects(:run_tests).with(language, exercise, s3_uri, container_slug, timeout).times(3).returns(success_data)

      settings = LanguageSettings.new(
        'timeout_ms' => timeout,
        'container_slug' => container_slug
      )

      TestRunner.new(submission_with_nil, conn, settings).test!
      TestRunner.new(submission_with_blank, conn, settings).test!
      TestRunner.new(submission_with_none, conn, settings).test!
    end

    def stub_data(status_code)
      @uuid = SecureRandom.uuid
      @status_code = status_code
      @message = "message"
      @results = {"foo" => "bar"}
      @timeout = 12312
      @container_slug = "foobar123"
      @s3_uri = "s3://test-exercism-submissions/test/testing/#{@uuid}"

      @submission = Submission.new(@uuid, :ruby, :bob)

      @settings = LanguageSettings.new(
        'timeout_ms' => @timeout,
        'container_slug' => @container_slug
      )

      @pc_data = {
        "status" => {"status_code" => @status_code, "message" => @message},
        "response" => @results
      }

      @platform_connection = mock
    end

    def test_works_with_200
      stub_data(200)

      @platform_connection.expects(:run_tests).with(:ruby, :bob, @s3_uri, @container_slug, @timeout).returns(@pc_data)
      Orchestrator::SPIClient.expects(:post_test_run).with(@uuid, 200, @message, @results)

      assert TestRunner.new(@submission, @platform_connection, @settings).test!
    end

    def test_works_with_400
      stub_data(400)

      @platform_connection.expects(:run_tests).with(:ruby, :bob, @s3_uri, @container_slug, @timeout).returns(@pc_data)
      Orchestrator::SPIClient.expects(:post_test_run).with(@uuid, 400, @message, @results)

      assert TestRunner.new(@submission, @platform_connection, @settings).test!
    end

    def test_no_workers_loop
      stub_data(503)

      @submission.expects(:increment_errors!)
      @submission.expects(:errored_too_many_times?).returns(false)
      @platform_connection.expects(:run_tests).times(40).with(:ruby, :bob, @s3_uri, @container_slug, @timeout).returns(@pc_data)

      test_runner = TestRunner.new(@submission, @platform_connection, @settings)
      test_runner.expects(:sleep).times(39).with(0.05)
      refute test_runner.test!
    end

    def test_no_workers_loop_with_threshold
      stub_data(503)

      @submission.expects(:increment_errors!)
      @submission.expects(:errored_too_many_times?).returns(true)
      @platform_connection.expects(:run_tests).times(40).with(:ruby, :bob, @s3_uri, @container_slug, @timeout).returns(@pc_data)
      Orchestrator::SPIClient.expects(:post_test_run).with(@uuid, 503, @message, @results)

      test_runner = TestRunner.new(@submission, @platform_connection, @settings)
      test_runner.expects(:sleep).times(39).with(0.05)
      assert test_runner.test!
    end

    def test_bad_exception_loop
      stub_data(500)

      @submission.expects(:increment_errors!)
      @submission.expects(:errored_too_many_times?).returns(false)
      @platform_connection.expects(:run_tests).times(2).raises(RuntimeError)

      test_runner = TestRunner.new(@submission, @platform_connection, @settings)
      refute test_runner.test!
    end

    def test_bad_exception_loop_with_submission_error_threshold
      stub_data(500)

      @submission.expects(:increment_errors!)
      @submission.expects(:errored_too_many_times?).returns(true)
      @platform_connection.expects(:run_tests).times(2).raises(RuntimeError)
      Orchestrator::SPIClient.expects(:post_unknown_error).with(@uuid, "RuntimeError")

      test_runner = TestRunner.new(@submission, @platform_connection, @settings)
      assert test_runner.test!
    end
  end
end
