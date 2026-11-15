# frozen_string_literal: true

require 'minitest/test_task'

Minitest::TestTask.create

desc 'Validate the RBS signatures and type-check lib/ with Steep'
task :typecheck do
  sh 'rbs validate'
  sh 'steep check'
end

task default: :test
