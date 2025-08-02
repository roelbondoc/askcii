# frozen_string_literal: true

require 'bundler/gem_tasks'
require 'rake/testtask'

Rake::TestTask.new(:test) do |t|
  t.libs << 'test'
  t.libs << 'lib'
  t.test_files = FileList['test/**/*_test.rb']
end

Rake::TestTask.new(:comprehensive) do |t|
  t.libs << 'test'
  t.libs << 'lib'
  t.test_files = FileList['test/comprehensive_test.rb']
end

Rake::TestTask.new(:simple) do |t|
  t.libs << 'test'
  t.libs << 'lib'
  t.test_files = FileList['test/simple_test.rb']
end

task default: :comprehensive
