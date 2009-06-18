require 'open3'
require 'thread'
require 'rbconfig'

USE_PATHNAME_MAKE_RELATIVE = false
CASE_SENSITIVE = RUBY_PLATFORM !~ /win32/

module DefBuild
	module Helpers
		def self.make_relative(path)
			make_relative2(path, Pathname.pwd)
		end
		
		if USE_PATHNAME_MAKE_RELATIVE
			def self.make_relative2(path, from)
				path.relative_path_from(from).to_s
			end
		else
			def self.make_relative2(path, from)
				basename = from.to_s
				path = path.to_s
				unless CASE_SENSITIVE
					path = path.downcase
					basename = basename.downcase
				end
				filenameparts = path.split(/\/|\\/)
				basenameparts = basename.split(/\/|\\/)

				return '.' if filenameparts == basenameparts

				while filenameparts.at(0) == basenameparts.at(0)
					filenameparts.shift
					basenameparts.shift
				end
				
				return ('..' + '/') * basenameparts.size + filenameparts.join('/')
			end
		end
		
		def self.is_child_dir_of(child, parent)
			self.make_relative2(child, parent) !~ /^\.\./
		end
		
		TRACE_MUTEX = Mutex.new
		
		def self.sh(verbose, *args)
			args = args.flatten.map do |arg|
				case arg
				when Pathname
					make_relative(arg)
				else
					arg
				end
			end
			
			if verbose
				puts args.join(' ')
				$stdout.flush
			end
			
			unless system(*args)
				unless File.exist?(args.first)
					trace "Executable '%s' does not exist", args.first
					exit(1)
				end
			
				trace 'build aborted (the following command failed:)'
				trace "%s", args.join(' ')
				exit(1)
			end
			nil
		end
		
		@@mtimes = {}
		def self.mtime(name)
			@@mtimes[name] ||= File.mtime(name)
		end
		
		@@existing_files = {}
		def self.exist?(name)
			@@existing_files[name] ||= File.exist?(name)
		end
		
		def self.newer?(i, o)
			if i.is_a?(Array)
				return false if i.empty?
				itime = i.map do |iname|
					return true unless exist?(iname)
					mtime(iname)
				end.max
			else
				return true unless exist?(i)
				itime = mtime(i)
			end
			
			if o.is_a?(Array)
				o.each do |oname|
					return true unless exist?(oname) && mtime(oname) >= itime
				end
			else
				return true unless exist?(o) && mtime(o) >= itime
			end
			
			return false
		end
		
		def self.trace(format, *args)
			args = args.map do |arg|
				arg.is_a?(Pathname) ? make_relative(arg) : arg
			end
			TRACE_MUTEX.synchronize do
				puts sprintf(format, *args)
				$stdout.flush
			end
		end
		
		def self.ruby_exe
			RbConfig::CONFIG['bindir'] + '/' + RbConfig::CONFIG['ruby_install_name'] + RbConfig::CONFIG['EXEEXT']
		end
		
		class TempEnv
			def initialize
				@old_values = {}
			end
			
			def []=(key, value)
				value = value.to_s if value.is_a?(Pathname)
				unless @old_values.include?(key)
					if ENV.include?(key)
						@old_values[key] = ENV[key]
					else
						@old_values[key] = :delete
					end
				end
				ENV[key] = value
			end
			
			def [](key)
				ENV[key]
			end
			
			def revert
				@old_values.each do |key, value|
					if value == :delete
						ENV.delete(key)
					else
						ENV[key] = value
					end
				end
			end
		end
		
		def self.temp_env
			env = TempEnv.new
			yield env
			env.revert
		end
	end
end

