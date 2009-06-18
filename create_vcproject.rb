$: << File.dirname(__FILE__)

require 'defbuild/projectwriterbase'

module DefBuild
	class VCProjectFileWriter < ProjectFileWriterBase
		def make_local(path)
			Helpers.make_relative(path).gsub(/\//, '\\')
		end
		
		def write(filename)
			defbuild = to_path(__FILE__).dirname + 'defbuild.rb'
			open_file(filename) do |file|
				version = '7.10'
				project_name = @project.name
				platform = 'Win32'
				executable_file_name = (@project.globals.target_name || @project.name) + '.exe'
				include_key_word = (version == '9.00' ? " IncludeSearchPath=\"" : " AdditionalIncludeDirectories=\"")
				file.puts "<?xml version=\"1.0\" encoding=\"Windows-1252\"?>\n<VisualStudioProject ProjectType=\"Visual C++\"	Version=\"#{version}\" Name=\"#{project_name}\" ProjectGUID=\"{955F73E0-6CC7-3213-8A61-FC349BCF0D03}\" Keyword=\"MakeFileProj\">"
				file.puts "\t<Platforms>\n\t\t<Platform Name=\"#{platform}\"/>\n\t</Platforms>"
				file.puts "\t<Configurations>"
				@builds.each do |build|
					target_dir = make_local(@project.path + 'build' + build)
					build_cmd = build_command(build)
					file.puts "\t\t<Configuration Name=\"#{build.gsub(/\//, '_')}|Win32\" OutputDirectory=\"#{target_dir}\" IntermediateDirectory=\"#{target_dir}\" ConfigurationType=\"0\">"
					file.write "\t\t\t<Tool	Name=\"VCNMakeTool\" BuildCommandLine=\"#{build_cmd} build\" ReBuildCommandLine=\"#{build_cmd} -r\" CleanCommandLine=\"#{build_cmd} -c\" Output=\"#{target_dir}\\#{executable_file_name}\""
					
					include_dirs = get_attribute(:cpp_include_dir, build)
					unless include_dirs.empty?
						file.write include_key_word
						file.write include_dirs.map {|einc| make_local(einc)}.join(';')
						file.write "\""
					end
					file.puts "/>"
					
					if platform == 'XBox 360'# and $gamebuild_dir
						raise 'TODO: implement'
						# write deployment options.
						file << "<Tool Name=\"VCX360DeploymentTool\" DeploymentFiles=\"$(RemoteRoot)=$(TargetPath);$(RemoteRoot)=#{$gamebuild_dir}\"/>"
					end
					
					file.puts "\t\t</Configuration>"
				end
				
				file.puts "\t</Configurations>"
				
				file.puts "\t<Files>"
				
				filenames = get_files
	
				# now put all the files...

				# first, recreate the folder structure of the files. We do it the following way : we split a folder from the beginning of the pathname. We check a hash for the given folder.
				# if its not there, we put it there, we put another hash in the hash for the folders in there.
				# if we, however, find a filename, we put it into an array that is in the hash under the name of '.'
				# after that, we get the keys of the hash, sort the list of keys and output the data recursiveley.

				folders = {}
				folders["."] = []	# the files here

				# now make relativ paths from the filenames
				filenames = filenames.map {|filename| make_local(filename) }

				# create a hash holding an array for all files in that folder and another hash for each directory.
				filenames.each do |filename|
					namefolders = filename.split(/\/|\\/)
					basename = namefolders.pop
					while namefolders.at(0) == ".."
						namefolders.shift
					end
					currenthash = folders
					namefolders.each do |f|
						if (not currenthash[f])
							currenthash[f] = {}
						end
						currenthash = currenthash[f]
					end
					
					if (not currenthash["."])
						currenthash["."] = []
					end
					currenthash["."] << filename
				end

				# now recurse through the hashes that each represent a folder
				write_folders(file, folders, 2)

				file << "\t</Files>\n"

				file << "\t<Globals>\n\t</Globals>\n"

				file << "</VisualStudioProject>"
			end
		end
		
		def write_folders(output, folderhash, indent)
			
			folders = folderhash.keys.sort
			# make sure the folders appear in front of the files.
			top = folders.at(0)
			if (top and top == ".")
				folders.push(folders.shift)
			end

			folders.each do |folder|
				if (folder == ".")
					filenames = folderhash[folder].sort
					filenames.each do |filename|
						output << ?\t.chr * (indent+1)
						output << "<File RelativePath=\"" + filename.gsub(/\//, '\\') + "\"/>\n"
					end
				else
					output << ?\t.chr * (indent+1)
					output << "<Filter Name=\"#{folder}\" Filter=\"\">\n"
					write_folders(output, folderhash[folder], indent+1)
					output << ?\t.chr * (indent+1)
					output << "</Filter>\n"
				end
			end
		end
	end
end

filename = ARGV.shift
platform = ARGV.shift
writer = DefBuild::VCProjectFileWriter.new(filename, ARGV)
writer.write(File.dirname(filename) + '/build/' + platform + "/#{writer.project.name}_#{platform}.vcproj")
