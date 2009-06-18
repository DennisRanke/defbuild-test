#!/usr/bin/env ruby

$: << File.dirname(__FILE__)

require 'optparse'
require 'defbuild/project'
require 'defbuild/builder'

build = ''
num_jobs = 1
clean = false

OptionParser.new do |opts|
	opts.banner = "Usage: defbuild.rb [OPTIONS] [PROJECT_DEF]"
	opts.on("-b", "--build BUILD", "Specifies the build") do |b|
		build = b
	end
	opts.on("-j", "--jobs NUM_JOBS", Integer, "Number of compile jobs to execute in parallel") do |jobs|
		num_jobs = jobs
	end
	opts.on("-c", "--clean", "Clean build directory") do
		clean = true
	end
	opts.on("-r", "--rebuild", "First clean build directory, then build") do
		clean = :rebuild
	end
end.parse!

filename = ARGV.shift || 'project.def'

project = DefBuild::Project.load(filename, build.split('/'))

builder = DefBuild::Builder.new

if clean
	builder.clean(project)
end

if !clean || clean == :rebuild
	builder.build(project, num_jobs)
end

puts 'build finished succesfully.'
